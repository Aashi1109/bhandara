import { faker } from '@faker-js/faker';

export type NumberRange = {
  min: number;
  max: number;
};

export type SeedOptions = {
  users: NumberRange;
  eventsPerUser: NumberRange;
  threadsPerEvent: NumberRange;
  messagesPerThread: NumberRange;
  password: string;
  emailPrefix: string;
  tagsPerEvent: NumberRange;
};

export type SeedStats = {
  usersCreated: number;
  eventsCreated: number;
  threadsCreated: number;
  messagesCreated: number;
  reactionsCreated: number;
  achievementsCreated: number;
  activitiesCreated: number;
};

export type UserMetrics = {
  eventCreated: number;
  messageCreated: number;
  reactionCreated: number;
  streakCurrent: number;
  streakLongest: number;
};

export const DEFAULT_OPTIONS: SeedOptions = {
  users: { min: 5, max: 5 },
  eventsPerUser: { min: 3, max: 3 },
  threadsPerEvent: { min: 2, max: 2 },
  messagesPerThread: { min: 12, max: 12 },
  password: 'SeedPass123!',
  emailPrefix: 'seed',
  tagsPerEvent: { min: 3, max: 3 },
};

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
    achievementsCreated: 0,
    activitiesCreated: 0,
  };
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
  const start = faker.date.soon({ days: 30 });
  const end = new Date(start.getTime() + faker.number.int({ min: 60, max: 240 }) * 60 * 1000);

  return {
    start,
    end,
  };
}
