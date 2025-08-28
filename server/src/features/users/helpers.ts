import { ITag, IUserSession } from "@/definitions/types";
import { IBaseUser } from "@/definitions/types";
import { RedisCache } from "@/features/cache";
import { jnparse, jnstringify } from "@/utils";
import { CACHE_NAMESPACE_CONFIG } from "@/constants";

const userCacheNamespace = CACHE_NAMESPACE_CONFIG.Users.namespace;
const userCacheTTL = CACHE_NAMESPACE_CONFIG.Users.ttl;
const sessionCacheNamespace = CACHE_NAMESPACE_CONFIG.Sessions.namespace;

const userCache = new RedisCache({
  namespace: userCacheNamespace,
  defaultTTLSeconds: userCacheTTL,
});
const sessionCache = new RedisCache({
  namespace: sessionCacheNamespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Sessions.ttl,
});

export const getUserCache = async (userId: string) => {
  return userCache.getItem<IBaseUser>(userId);
};

export const setUserCache = async (
  userId: string,
  user: IBaseUser,
  ttl = userCacheTTL
) => {
  return userCache.setItem(userId, user, ttl);
};

export const deleteUserCache = async (userId: string) => {
  return userCache.deleteItem(userId);
};

export const deleteAllUserCache = async (userId: string, user?: IBaseUser) => {
  const sessionMap = await userCache.getHKeys(`${userId}:sessions`);
  const sessionIds = Object.keys(sessionMap);

  const pipeline = userCache.getPipeline();
  pipeline.del(`${userCacheNamespace}:${userId}`);
  pipeline.del(`${userCacheNamespace}:${userId}:sessions`);
  pipeline.del(`${userCacheNamespace}:${userId}:interests`);

  if (user?.email) pipeline.del(`${userCacheNamespace}:${user.email}`);
  if (user?.username) pipeline.del(`${userCacheNamespace}:${user.username}`);

  sessionIds.forEach((sessionId) => {
    pipeline.del(`${sessionCacheNamespace}:${sessionId}`);
  });
  return pipeline.exec();
};

export const getUserCacheByEmail = async (email: string) => {
  const id = await userCache.getItem<string>(email);
  if (!id) return null;
  return userCache.getItem<IBaseUser>(id);
};

export const setUserCacheByEmail = async (
  email: string,
  user: IBaseUser,
  ttl = userCacheTTL
) => {
  return userCache.setItem(email, user.id, ttl);
};

export const getUserCacheByUsername = async (username: string) => {
  const id = await userCache.getItem<string>(username);
  if (!id) return null;
  return userCache.getItem<IBaseUser>(id);
};

export const setUserCacheByUsername = async (
  username: string,
  user: IBaseUser,
  ttl = userCacheTTL
) => {
  return userCache.setItem(username, user.id, ttl);
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

  // TODO: TO be used with upstash redis
  // Extract actual session data from results
  // const sessions = results
  //   .map((result: Record<string, any>) => {
  //     return {
  //       device: result.userAgent,
  //       createdAt: result.createdAt,
  //       location: result.location,
  //     };
  //   })
  //   .filter(Boolean);

  // TODO: TO be used with ioredis
  const sessions = results.map(
    ([, result]: [Error, Record<string, any>], index: number) => {
      result = jnparse(result);
      if (!result) return null;
      return {
        id: sessionIds[index],
        device: result.userAgent,
        createdAt: result.createdAt,
        location: result.location,
      };
    }
  );

  return sessions.filter(Boolean);
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
  await userCache.setHKey(
    `${userId}:sessions`,
    sessionId,
    expiration.toISOString()
  );
  return sessionCache.setItem(sessionId, data, ttl);
};

export const getUserSessionCache = async (
  sessionId: string
): Promise<IUserSession | null> => {
  return sessionCache.getItem(sessionId);
};

export const updateUserSessionCache = async (
  sessionId: string,
  data: IUserSession
) => {
  return sessionCache.updateValue(sessionId, data);
};

export const deleteUserSessionCache = async (
  userId: string,
  sessionId: string
) => {
  return Promise.all([
    sessionCache.deleteItem(sessionId),
    userCache.deleteHKey(`${userId}:sessions`, sessionId),
  ]);
};

export const getSafeUser = (user: IBaseUser) => {
  const _user = { ...user };
  delete _user.password;
  delete _user.meta.auth;
  return _user;
};

export const getLeanUser = (user: IBaseUser) => {
  const safe = getSafeUser(user);
  const { id, name, createdAt, deletedAt, username, email } = safe;
  return { id, name, createdAt, deletedAt, username, email } as IBaseUser;
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

export const bulkSetUserCache = async (users: IBaseUser[]): Promise<"OK"> => {
  const pipeline = userCache.getPipeline();
  users.forEach((user) => {
    pipeline.set(`${userCacheNamespace}:${user.id}`, jnstringify(user));
    pipeline.set(`${userCacheNamespace}:${user.email}`, user.id);
    pipeline.expire(`${userCacheNamespace}:${user.email}`, userCacheTTL);
    pipeline.set(`${userCacheNamespace}:${user.username}`, user.id);
    pipeline.expire(`${userCacheNamespace}:${user.username}`, userCacheTTL);
    pipeline.expire(`${userCacheNamespace}:${user.id}`, userCacheTTL);
  });
  await pipeline.exec();
  return "OK";
};

export const bulkGetUserCache = async (ids: string[]): Promise<IBaseUser[]> => {
  const pipeline = userCache.getPipeline();
  ids.forEach((id) => {
    pipeline.get(`${userCacheNamespace}:${id}`);
  });
  const results = await pipeline.exec();

  const users = results.reduce((acc, [_, result]) => {
    const user = jnparse(result);
    if (!user) return acc;
    acc.push(user);
    return acc;
  }, [] as IBaseUser[]);

  return users;
};
