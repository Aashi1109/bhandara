import type { ITag, IUserSession, IBaseUser } from '@/common/definitions/types';
import { RedisCache } from '@/features/cache';
import { cacheKeys } from '@/features/cache/keys';
import { decryptRecordFields, encryptRecordFields, jnparse, jnstringify } from '@/common/utils';
import { CACHE_NAMESPACE_CONFIG, REDIS_CONNECTION_NAMES } from '@/common/constants';
import logger from '@/common/logger';

const userCacheNamespace = CACHE_NAMESPACE_CONFIG.Users.namespace;
const userCacheTTL = CACHE_NAMESPACE_CONFIG.Users.ttl;
const sessionCacheNamespace = CACHE_NAMESPACE_CONFIG.Sessions.namespace;

const userCache = new RedisCache({
  connectionName: REDIS_CONNECTION_NAMES.Cache,
  namespace: userCacheNamespace,
  defaultTTLSeconds: userCacheTTL,
});
const sessionCache = new RedisCache({
  connectionName: REDIS_CONNECTION_NAMES.Sessions,
  namespace: sessionCacheNamespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Sessions.ttl,
});

const SESSION_SECRET_FIELDS = ['accessToken', 'refreshToken'] as const;
const USER_CACHE_ENCRYPTED_FIELDS = ['email', '__sid'] as const;

const encryptCachedUser = (user: IBaseUser) => encryptRecordFields(user, USER_CACHE_ENCRYPTED_FIELDS);
const decryptCachedUser = (user: IBaseUser | null): IBaseUser | null => {
  if (!user) {
    return null;
  }

  return decryptRecordFields(user, USER_CACHE_ENCRYPTED_FIELDS);
};

const decryptSessionSecrets = (session: IUserSession | null): IUserSession | null => {
  if (!session) {
    return null;
  }

  return decryptRecordFields(session, SESSION_SECRET_FIELDS);
};

export const getUserCache = async (userId: string) => {
  return decryptCachedUser(await userCache.getItem<IBaseUser>(userId));
};

export const setUserCache = async (userId: string, user: IBaseUser, ttl = userCacheTTL) => {
  return userCache.setItem(userId, encryptCachedUser(user), ttl);
};

export const deleteUserCache = async (userId: string) => {
  return userCache.deleteItem(userId);
};

export const deleteAllUserCache = async (userId: string, user?: IBaseUser) => {
  // Read sessions before wiping the hash
  const sessionMap = await userCache.getHKeys(`${userId}:sessions`);
  const sessionIds = Object.keys(sessionMap);

  // Wipe everything under this userId in one pattern match (userId, userId:sessions, userId:interests, userId:settings, etc.)
  await userCache.invalidateCache(`${userId}*`);

  // Email and username keys are stored independently — delete them explicitly
  const pipeline = userCache.getPipeline();
  if (user?.email) pipeline.del(`${userCacheNamespace}:${cacheKeys.userEmailLookup(user.email)}`);
  if (user?.username) pipeline.del(`${userCacheNamespace}:${cacheKeys.userUsernameLookup(user.username)}`);

  // Delete individual session entries from the sessions cache
  sessionIds.forEach((sessionId) => {
    pipeline.del(`${sessionCacheNamespace}:${sessionId}`);
  });

  return pipeline.exec();
};

export const getUserCacheByEmail = async (email: string) => {
  const id = await userCache.getItem<string>(cacheKeys.userEmailLookup(email));
  if (!id) return null;
  return decryptCachedUser(await userCache.getItem<IBaseUser>(id));
};

export const setUserCacheByEmail = async (email: string, user: IBaseUser, ttl = userCacheTTL) => {
  return userCache.setItem(cacheKeys.userEmailLookup(email), user.id, ttl);
};

export const getUserCacheByUsername = async (username: string) => {
  const id = await userCache.getItem<string>(cacheKeys.userUsernameLookup(username));
  if (!id) return null;
  return decryptCachedUser(await userCache.getItem<IBaseUser>(id));
};

export const setUserCacheByUsername = async (username: string, user: IBaseUser, ttl = userCacheTTL) => {
  return userCache.setItem(cacheKeys.userUsernameLookup(username), user.id, ttl);
};

export const getUserSessionCacheList = async (userId: string) => {
  // Step 1: Get all session IDs from the user's hash
  const sessionMap = await userCache.getHKeys(`${userId}:sessions`);

  if (!sessionMap || Object.keys(sessionMap).length === 0) {
    return [];
  }

  const sessionIds = Object.keys(sessionMap);

  // Step 2: Fetch all session objects using pipeline
  const pipeline = sessionCache.getPipeline();
  sessionIds.forEach((sessionId) => {
    pipeline.get(`${sessionCacheNamespace}:${sessionId}`);
  });

  const results = await pipeline.exec();

  const sessions: any[] = [];
  const staleSessionIds: string[] = [];

  results!.forEach(([, rawResult]: [Error | null, unknown], index: number) => {
    const result = jnparse(rawResult);
    if (!result) {
      // Mark for lazy cleanup
      staleSessionIds.push(sessionIds[index]);
    } else {
      sessions.push({
        id: sessionIds[index],
        device: result.userAgent,
        createdAt: result.createdAt,
        location: result.location,
      });
    }
  });

  // Step 3: Lazy cleanup of stale session IDs from the hash
  if (staleSessionIds.length > 0) {
    const cleanupPipeline = userCache.getPipeline();
    staleSessionIds.forEach((sessionId) => {
      cleanupPipeline.hdel(`${userCacheNamespace}:${userId}:sessions`, sessionId);
    });
    // Fire and forget cleanup
    cleanupPipeline.exec().catch((err) => {
      logger.error('Failed to clean up stale session IDs:', err);
    });
  }

  return sessions;
};

export const setUserSessionCache = async ({
  userId,
  sessionId,
  data,
  ttl = 3600 * 24 * 30,
}: {
  userId: string;
  sessionId: string;
  data: IUserSession;
  ttl?: number;
}) => {
  const expiration = new Date(Date.now() + ttl * 1000);
  // sliding expiration for the main session hash
  await userCache.setHKey(`${userId}:sessions`, sessionId, expiration.toISOString(), ttl);
  return sessionCache.setItem(sessionId, encryptRecordFields(data, SESSION_SECRET_FIELDS), ttl);
};

export const getUserSessionCache = async (sessionId: string): Promise<IUserSession | null> => {
  return decryptSessionSecrets(await sessionCache.getItem(sessionId));
};

export const updateUserSessionCache = async (sessionId: string, data: IUserSession) => {
  return sessionCache.updateValue(sessionId, encryptRecordFields(data, SESSION_SECRET_FIELDS));
};

export const deleteUserSessionCache = async (userId: string, sessionId: string) => {
  return Promise.all([sessionCache.deleteItem(sessionId), userCache.deleteHKey(`${userId}:sessions`, sessionId)]);
};

export const getSafeUser = (user: IBaseUser): IBaseUser & { isSocialLogin: boolean } => {
  const _user = { ...user } as Record<string, any>;
  const provider = _user.meta?.auth?.provider;
  delete _user.__sid;
  delete _user.password;
  delete _user.meta?.auth?.accessToken;
  delete _user.meta?.auth?.refreshToken;
  return { ..._user, isSocialLogin: provider !== 'email' } as IBaseUser & { isSocialLogin: boolean };
};

export const getPublicUser = (user: IBaseUser) => {
  const safe = getSafeUser(user) as Record<string, any>;
  delete safe.email;
  delete safe.gender;
  delete safe.address;
  delete safe.meta;
  delete safe.mediaId;
  return safe;
};

export const getLeanUser = (user: IBaseUser) => {
  const safe = getSafeUser(user);
  const { id, name, createdAt, username, email } = safe;
  return { id, name, createdAt, username, email } as IBaseUser;
};

export const getUserInterestsCache = (userId: string) => {
  return userCache.getItem<ITag[]>(`${userId}:interests`);
};

export const setUserInterestsCache = (userId: string, interests: ITag[]) => {
  return userCache.setItem(`${userId}:interests`, interests);
};

export const deleteUserInterestsCache = (userId: string) => {
  return userCache.deleteItem(`${userId}:interests`);
};

export const getUserSettingsCache = <T>(userId: string) => {
  return userCache.getItem<T>(`${userId}:settings`);
};

export const setUserSettingsCache = <T>(userId: string, settings: T) => {
  return userCache.setItem(`${userId}:settings`, settings, userCacheTTL);
};

export const bulkSetUserCache = async (users: IBaseUser[]): Promise<'OK'> => {
  const pipeline = userCache.getPipeline();
  users.forEach((user) => {
    pipeline.set(`${userCacheNamespace}:${user.id}`, jnstringify(encryptCachedUser(user)), 'EX', userCacheTTL);
    pipeline.set(`${userCacheNamespace}:${cacheKeys.userEmailLookup(user.email)}`, user.id, 'EX', userCacheTTL);
    if (user.username) {
      pipeline.set(`${userCacheNamespace}:${cacheKeys.userUsernameLookup(user.username)}`, user.id, 'EX', userCacheTTL);
    }
  });
  await pipeline.exec();
  return 'OK';
};

export const bulkGetUserCache = async (ids: string[]): Promise<IBaseUser[]> => {
  const pipeline = userCache.getPipeline();
  ids.forEach((id) => {
    pipeline.get(`${userCacheNamespace}:${id}`);
  });
  const results = await pipeline.exec();

  const users = (results || []).reduce((acc, [, result]) => {
    const user = typeof result === 'string' ? (jnparse(result) as IBaseUser) : null;
    if (!user) return acc;
    acc.push(decryptCachedUser(user)!);
    return acc;
  }, [] as IBaseUser[]);

  return users;
};
