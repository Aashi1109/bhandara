import { NumberRange, type SeedOptions } from './types';

export const REACTION_EMOJIS = ['❤️', '🔥', '👏', '🍲', '😋', '🙌'];
export const THREADS_EMPTY_PROBABILITY = 0.2;
export const MESSAGES_EMPTY_PROBABILITY = 0.35;
export const DEFAULT_MAX_PRIMARY_ROWS = 5_000_000n;
export const DB_BULK_INSERT_CHUNK_SIZE = Number(process.env.SEED_DB_BATCH_SIZE || 12000);
export const AUTH_SIGNUP_BATCH_SIZE = Number(process.env.SEED_AUTH_BATCH_SIZE || 16);

export const DEFAULT_OPTIONS: SeedOptions = {
  users: { min: 5, max: 5 },
  eventsPerUser: { min: 3, max: 3 },
  threadsPerEvent: { min: 2, max: 2 },
  messagesPerThread: { min: 12, max: 12 },
  password: 'SeedPass123!',
  emailPrefix: 'seed',
  tagsPerEvent: { min: 3, max: 3 },
};
