import { faker } from '@faker-js/faker';
import type { Transaction } from 'sequelize';
import { getUUIDv7 } from '@/src/common/helpers';
import type { NumberRange, SeedCoordinatorUser, SeedOptions, SeedStats, UserMetrics } from './types';
import { DEFAULT_OPTIONS, DEFAULT_MAX_PRIMARY_ROWS, DB_BULK_INSERT_CHUNK_SIZE } from './constants';

type SeedHierarchyLevel = 'event' | 'thread' | 'message';

function stableHash(input: string) {
  let hash = 2166136261;

  for (let index = 0; index < input.length; index += 1) {
    hash ^= input.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }

  return hash >>> 0;
}

export function stableUnitRandom(key: string) {
  return stableHash(key) / 4294967296;
}

export function logSeedProgress(message: string) {
  console.log(`[seed:fresh] ${new Date().toISOString()} ${message}`);
}

export function formatSeedStep(scope: string, phase: string, detail?: string) {
  const normalizedScope = scope.startsWith('[') ? scope : `[${scope}]`;
  const normalizedPhase = phase.startsWith('[') ? phase : `[${phase}]`;
  return detail ? `${normalizedScope} ${normalizedPhase} ${detail}` : `${normalizedScope} ${normalizedPhase}`;
}

export function formatBigInt(value: bigint) {
  return value.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

export function parseRange(value: string | undefined, fallback: NumberRange): NumberRange {
  if (!value) return fallback;

  if (!value.includes(':')) {
    const parsed = Number(value);
    return Number.isFinite(parsed) && parsed >= 0 ? { min: parsed, max: parsed } : fallback;
  }

  const [rawMin, rawMax] = value.split(':');
  const min = Number(rawMin);
  const max = Number(rawMax);

  if (!Number.isFinite(min) || !Number.isFinite(max) || min < 0 || max < min) {
    return fallback;
  }

  return { min, max };
}

export function resolveRange(range: NumberRange) {
  return faker.number.int({ min: range.min, max: range.max });
}

export function resolveRangeForKey(range: NumberRange, key: string) {
  if (range.max <= range.min) {
    return range.max;
  }

  return range.min + Math.floor(stableUnitRandom(key) * (range.max - range.min + 1));
}

export function formatRange(range: NumberRange) {
  return range.min === range.max ? `${range.min}` : `${range.min}:${range.max}`;
}

export function buildSeedStats(): SeedStats {
  return {
    usersCreated: 0,
    eventsCreated: 0,
    threadsCreated: 0,
    messagesCreated: 0,
    reactionsCreated: 0,
    savesCreated: 0,
    achievementsCreated: 0,
    activitiesCreated: 0,
  };
}

export function isTimeoutLikeError(error: unknown) {
  if (!(error instanceof Error)) {
    return false;
  }

  const message = error.message.toLowerCase();
  return (
    message.includes('timeout') ||
    message.includes('query read timeout') ||
    message.includes('statement timeout') ||
    message.includes('connection acquire timeout')
  );
}

export function isTransientDatabaseError(error: unknown) {
  if (!(error instanceof Error)) {
    return false;
  }

  const message = error.message.toLowerCase();
  return (
    isTimeoutLikeError(error) ||
    message.includes('connection terminated unexpectedly') ||
    message.includes('terminating connection due to administrator command') ||
    message.includes('server closed the connection unexpectedly') ||
    message.includes('connection error') ||
    message.includes('connection reset') ||
    message.includes('econnreset') ||
    message.includes('connection terminated') ||
    message.includes('connection refused') ||
    message.includes('could not connect') ||
    message.includes('sequelizeconnectionerror') ||
    message.includes('connection acquire timeout')
  );
}

export function chunkArray<T>(items: T[], chunkSize: number): T[][] {
  if (chunkSize <= 0) {
    throw new Error('chunkSize must be greater than 0');
  }

  const chunks: T[][] = [];

  for (let index = 0; index < items.length; index += chunkSize) {
    chunks.push(items.slice(index, index + chunkSize));
  }

  return chunks;
}

function buildUserMetrics(): UserMetrics {
  return {
    eventCreated: 0,
    messageCreated: 0,
    reactionCreated: 0,
    streakCurrent: faker.number.int({ min: 1, max: 10 }),
    streakLongest: 0,
  };
}

export function getOrCreateMetrics(metricsByUserId: Map<string, UserMetrics>, userId: string): UserMetrics {
  const existing = metricsByUserId.get(userId);
  if (existing) return existing;

  const created = buildUserMetrics();
  created.streakLongest = faker.number.int({ min: created.streakCurrent, max: created.streakCurrent + 14 });
  metricsByUserId.set(userId, created);
  return created;
}

export function parseOptionalCount(value: string | undefined): number | undefined {
  if (!value) return undefined;

  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return undefined;
  }

  return Math.floor(parsed);
}

export function parseOptionalBoolean(value: string | undefined): boolean | undefined {
  if (!value) return undefined;

  const normalized = value.trim().toLowerCase();
  if (['true', '1', 'yes', 'y'].includes(normalized)) return true;
  if (['false', '0', 'no', 'n'].includes(normalized)) return false;
  return undefined;
}

export function parseOptions(argv: string[]): SeedOptions {
  const values = new Map<string, string>();

  argv.forEach((arg) => {
    if (!arg.startsWith('--')) return;
    const [key, ...rest] = arg.slice(2).split('=');
    values.set(key, rest.join('='));
  });

  return {
    users: parseRange(values.get('users'), DEFAULT_OPTIONS.users),
    eventsPerUser: parseRange(values.get('events-per-user'), DEFAULT_OPTIONS.eventsPerUser),
    threadsPerEvent: parseRange(values.get('threads-per-event'), DEFAULT_OPTIONS.threadsPerEvent),
    messagesPerThread: parseRange(values.get('messages-per-thread'), DEFAULT_OPTIONS.messagesPerThread),
    totalEvents: parseOptionalCount(values.get('total-events')),
    totalThreads: parseOptionalCount(values.get('total-threads')),
    totalMessages: parseOptionalCount(values.get('total-messages')),
    reuseExistingUsers: parseOptionalBoolean(values.get('reuse-existing-users')) || false,
    reuseMaxUsers: parseOptionalCount(values.get('reuse-max-users')),
    seedWorkers: parseOptionalCount(values.get('seed-workers')),
    password: values.get('password') || DEFAULT_OPTIONS.password,
    emailPrefix: values.get('email-prefix') || DEFAULT_OPTIONS.emailPrefix,
    tagsPerEvent: parseRange(values.get('tags-per-event'), DEFAULT_OPTIONS.tagsPerEvent),
  };
}

export function buildAddress() {
  const latitude = faker.number.float({ min: 12, max: 28, fractionDigits: 6 });
  const longitude = faker.number.float({ min: 72, max: 88, fractionDigits: 6 });

  return {
    address: faker.location.streetAddress({ useFullAddress: true }),
    latitude,
    longitude,
    coordinates: {
      latitude,
      longitude,
    },
  };
}

export function buildEventLocation() {
  const address = buildAddress();
  return {
    ...address,
    venue: faker.company.name(),
  };
}

export function buildTimings() {
  const startTime = faker.date.soon({ days: 30 });
  const endTime = new Date(startTime.getTime() + faker.number.int({ min: 60, max: 240 }) * 60 * 1000);

  return {
    startTime,
    endTime,
  };
}

export function resolveSparseRange(range: NumberRange, zeroProbability: number) {
  if (range.max === 0) return 0;
  return faker.datatype.boolean({ probability: zeroProbability }) ? 0 : resolveRange(range);
}

export function deriveHierarchyLowerBound(max: number, level: SeedHierarchyLevel) {
  if (max <= 0) {
    return 0;
  }

  const ratio = level === 'event' ? 0.5 : level === 'thread' ? 0.3 : 0.1;
  return Math.min(max, Math.max(1, Math.floor(max * ratio)));
}

export function deriveHierarchicalRange(range: NumberRange, level: SeedHierarchyLevel): NumberRange {
  if (range.max <= 0) {
    return { min: 0, max: 0 };
  }

  if (range.min !== range.max) {
    return range;
  }

  return {
    min: deriveHierarchyLowerBound(range.max, level),
    max: range.max,
  };
}

export function resolveHierarchicalSparseRange(range: NumberRange, zeroProbability: number, level: SeedHierarchyLevel) {
  if (range.max === 0) return 0;
  if (faker.datatype.boolean({ probability: zeroProbability })) return 0;
  return resolveRange(deriveHierarchicalRange(range, level));
}

export function resolveHierarchicalSparseRangeForKey(
  range: NumberRange,
  zeroProbability: number,
  level: SeedHierarchyLevel,
  key: string,
) {
  if (range.max === 0) return 0;
  if (stableUnitRandom(`${key}:zero`) < zeroProbability) return 0;
  return resolveRangeForKey(deriveHierarchicalRange(range, level), `${key}:value`);
}

export function distributeTotalAcrossKeys(
  total: number,
  keys: string[],
  options?: {
    baseWeights?: number[];
    zeroProbability?: number;
    randomnessFactor?: number;
  },
) {
  if (keys.length === 0) return [];
  if (total <= 0) return Array(keys.length).fill(0);

  const baseWeights = options?.baseWeights ?? keys.map(() => 1);
  const randomnessFactor = Math.max(0, Math.min(options?.randomnessFactor ?? 1, 1));
  const weights = keys.map((key, index) => {
    const baseWeight = Math.max(0, baseWeights[index] ?? 0);
    if (baseWeight <= 0) return 0;
    if ((options?.zeroProbability ?? 0) > 0 && stableUnitRandom(`${key}:active`) < (options?.zeroProbability ?? 0)) {
      return 0;
    }

    if (randomnessFactor === 0) {
      return baseWeight;
    }

    const jitter = 1 - randomnessFactor / 2 + stableUnitRandom(`${key}:weight`) * randomnessFactor;
    return baseWeight * jitter;
  });

  let weightSum = weights.reduce((sum, weight) => sum + weight, 0);
  if (weightSum <= 0) {
    for (let index = 0; index < keys.length; index += 1) {
      weights[index] = Math.max(0, baseWeights[index] ?? 0);
    }
    weightSum = weights.reduce((sum, weight) => sum + weight, 0);
  }

  if (weightSum <= 0) {
    return Array(keys.length).fill(0);
  }

  const raw = weights.map((weight) => (total * weight) / weightSum);
  const counts = raw.map((value) => Math.floor(value));
  let remaining = total - counts.reduce((sum, count) => sum + count, 0);

  const rankedIndices = raw
    .map((value, index) => ({
      index,
      fractional: value - Math.floor(value),
      tieBreaker: stableUnitRandom(`${keys[index]}:remainder`),
    }))
    .sort((left, right) => {
      if (right.fractional !== left.fractional) {
        return right.fractional - left.fractional;
      }

      return right.tieBreaker - left.tieBreaker;
    });

  let cursor = 0;
  while (remaining > 0 && rankedIndices.length > 0) {
    const current = rankedIndices[cursor % rankedIndices.length];
    if (weights[current.index] > 0) {
      counts[current.index] += 1;
      remaining -= 1;
    }
    cursor += 1;
  }

  return counts;
}

export function getEngagementViewCount(entityType: 'event' | 'thread' | 'message') {
  if (entityType === 'event') return faker.number.int({ min: 0, max: 800 });
  if (entityType === 'thread') return faker.number.int({ min: 0, max: 250 });
  return faker.number.int({ min: 0, max: 80 });
}

export function estimateSeedPrimaryRows(options: SeedOptions) {
  const users = BigInt(options.users.max);
  const events =
    options.totalEvents !== undefined ? BigInt(options.totalEvents) : users * BigInt(options.eventsPerUser.max);
  const threads =
    options.totalThreads !== undefined ? BigInt(options.totalThreads) : events * BigInt(options.threadsPerEvent.max);
  const messages =
    options.totalMessages !== undefined
      ? BigInt(options.totalMessages)
      : threads * BigInt(options.messagesPerThread.max);

  return {
    users,
    events,
    threads,
    messages,
    total: users + events + threads + messages,
  };
}

export function assertSeedWorkloadWithinGuard(options: SeedOptions) {
  const estimates = estimateSeedPrimaryRows(options);
  const maxPrimaryRows = BigInt(process.env.SEED_FRESH_MAX_PRIMARY_ROWS || DEFAULT_MAX_PRIMARY_ROWS.toString());
  const guardDisabled = process.env.SEED_FRESH_DISABLE_GUARD === 'true';

  logSeedProgress(
    `Projected max primary rows: users=${formatBigInt(estimates.users)}, events=${formatBigInt(estimates.events)}, threads=${formatBigInt(estimates.threads)}, messages=${formatBigInt(estimates.messages)}, total=${formatBigInt(estimates.total)}`,
  );

  if (guardDisabled || estimates.total <= maxPrimaryRows) {
    return;
  }

  throw new Error(
    `Projected primary rows ${formatBigInt(estimates.total)} exceed safety limit ${formatBigInt(maxPrimaryRows)}. The flags --events-per-user, --threads-per-event, and --messages-per-thread are multipliers. For totals, use --total-events, --total-threads, and --total-messages instead. Reduce seed counts or set SEED_FRESH_DISABLE_GUARD=true / SEED_FRESH_MAX_PRIMARY_ROWS=<higher number> if you really want to run it.`,
  );
}

export async function bulkCreateInChunks<T extends object>(
  model: { bulkCreate(rows: T[], options: { transaction: Transaction; returning: boolean }): Promise<unknown> },
  rows: T[],
  transaction: Transaction,
  label: string,
  chunkSize = DB_BULK_INSERT_CHUNK_SIZE,
) {
  if (rows.length === 0) {
    logSeedProgress(`${label} skip rows=0`);
    return;
  }

  const chunks = chunkArray(rows, chunkSize);
  logSeedProgress(`${label} insert start rows=${rows.length} chunks=${chunks.length}`);

  for (const [chunkIndex, chunk] of chunks.entries()) {
    await bulkCreateChunkWithRetry(model, chunk, transaction, label, chunkIndex + 1, chunks.length);
  }

  logSeedProgress(`${label} insert complete`);
}

async function bulkCreateChunkWithRetry<T extends object>(
  model: { bulkCreate(rows: T[], options: { transaction: Transaction; returning: boolean }): Promise<unknown> },
  chunk: T[],
  transaction: Transaction,
  label: string,
  chunkNumber: number,
  totalChunks: number,
  splitDepth = 0,
) {
  logSeedProgress(
    `${label} insert chunk=${chunkNumber}/${totalChunks} rows=${chunk.length}${splitDepth > 0 ? ` splitDepth=${splitDepth}` : ''}`,
  );

  try {
    await model.bulkCreate(chunk, {
      transaction,
      returning: false,
    });
  } catch (error) {
    if (!isTimeoutLikeError(error) || chunk.length <= 1) {
      throw error;
    }

    const midpoint = Math.ceil(chunk.length / 2);
    const left = chunk.slice(0, midpoint);
    const right = chunk.slice(midpoint);

    logSeedProgress(
      `${label} insert timeout chunk=${chunkNumber}/${totalChunks} rows=${chunk.length} retry=split left=${left.length} right=${right.length}`,
    );

    await bulkCreateChunkWithRetry(model, left, transaction, label, chunkNumber, totalChunks, splitDepth + 1);
    await bulkCreateChunkWithRetry(model, right, transaction, label, chunkNumber, totalChunks, splitDepth + 1);
  }
}

export async function flushPendingRows<T extends object>(
  model: { bulkCreate(rows: T[], options: { transaction: Transaction; returning: boolean }): Promise<unknown> },
  rows: T[],
  transaction: Transaction,
  label: string,
  chunkSize = DB_BULK_INSERT_CHUNK_SIZE,
) {
  if (rows.length === 0) return;

  const batch = rows.splice(0, rows.length);
  await bulkCreateInChunks(model, batch, transaction, label, chunkSize);
}

export function buildSeedUserEmailLikePattern(emailPrefix: string) {
  return `${emailPrefix}.%@zentry.dev`;
}

export function computeWorkerCount(requestedWorkers: number | undefined, finalUserCount: number, cpuCount: number) {
  if (finalUserCount <= 0) return 0;

  const defaultWorkers = Math.min(Math.max(cpuCount, 1), finalUserCount, 8);
  if (!requestedWorkers || requestedWorkers <= 0) {
    return defaultWorkers;
  }

  return Math.min(requestedWorkers, finalUserCount, 32);
}

export function shardSeedUsers(users: SeedCoordinatorUser[], workerCount: number) {
  if (workerCount <= 1 || users.length <= 1) {
    return users.length > 0 ? [users] : [];
  }

  const shardCount = Math.min(workerCount, users.length);
  const shards: SeedCoordinatorUser[][] = Array.from({ length: shardCount }, () => []);

  users.forEach((user, index) => {
    shards[index % shardCount].push(user);
  });

  return shards.filter((shard) => shard.length > 0);
}
