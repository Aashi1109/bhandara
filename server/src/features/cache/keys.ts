import { hashForCacheKey, hashForLookup } from '@/utils';

type CacheEntityType = 'events' | 'threads' | 'messages' | 'users';

const ENTITY_CODES: Record<CacheEntityType, string> = {
  events: 'e',
  threads: 't',
  messages: 'm',
  users: 'u',
};

const compact = (...parts: Array<string | null | undefined>) =>
  parts.filter((part): part is string => !!part && part.length > 0).join(':');

const hashed = (value: string) => hashForLookup(value) ?? '';
const shortHashed = (value: string) => hashForCacheKey(value) ?? '';

export const entityCode = (entityType: CacheEntityType) => ENTITY_CODES[entityType];

export const cacheKeys = {
  engagementAggregate(entityType: CacheEntityType, id: string) {
    return compact('eg', entityCode(entityType), id);
  },
  engagementViewDedupe(entityType: CacheEntityType, id: string, dayKey: string, viewerKey: string) {
    return compact('egv', entityCode(entityType), id, dayKey, viewerKey);
  },
  stats(entityType: Exclude<CacheEntityType, 'users'>, id: string) {
    return compact(entityCode(entityType), id);
  },
  activityItem(id: string) {
    return compact('i', id);
  },
  userActivityPattern(userId: string) {
    return compact('u', userId, 'a', '*');
  },
  userUpdatesPattern(userId: string) {
    return compact('u', userId, 'u', '*');
  },
  achievementProgress(userId: string) {
    return compact('u', userId, 'p');
  },
  achievementPattern(userId: string) {
    return compact('u', userId, '*');
  },
  exploreCursor(userId: string) {
    return compact('u', userId, 'c');
  },
  userEmailLookup(email: string) {
    return compact('ul', 'e', shortHashed(email));
  },
  userUsernameLookup(username: string) {
    return compact('ul', 'u', hashed(username));
  },
  passwordResetOtp(email: string) {
    return compact('pwd', 'otp', hashed(email));
  },
  passwordResetToken(token: string) {
    return compact('pwd', 'tok', hashed(token));
  },
};
