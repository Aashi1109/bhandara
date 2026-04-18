import { faker } from '@faker-js/faker';
import AuthService from '@/src/features/auth/service';
import { AUTH_SIGNUP_BATCH_SIZE } from './constants';
import type { SeedOptions, SeededAuthUser } from './types';
import { chunkArray, logSeedProgress, resolveRange } from './utils';

const AUTH_RATE_LIMIT_MAX_RETRIES = Number(process.env.SEED_AUTH_MAX_RETRIES || 8);
const AUTH_RATE_LIMIT_BASE_DELAY_MS = Number(process.env.SEED_AUTH_BASE_DELAY_MS || 3000);
const AUTH_RATE_LIMIT_MAX_DELAY_MS = Number(process.env.SEED_AUTH_MAX_DELAY_MS || 30000);

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isRateLimitError(error: unknown) {
  if (!error || typeof error !== 'object') return false;

  const candidate = error as {
    status?: number;
    code?: string;
    message?: string;
    name?: string;
  };

  return (
    candidate.status === 429 ||
    candidate.code === 'over_request_rate_limit' ||
    /rate limit|too many requests/i.test(candidate.message || '') ||
    /rate limit/i.test(candidate.name || '')
  );
}

function getRetryAfterHeader(error: unknown) {
  const candidate = error as {
    headers?: Headers | Record<string, string | undefined>;
    response?: { headers?: Headers | Record<string, string | undefined> };
  };

  const directHeaders = candidate?.headers;
  if (directHeaders instanceof Headers) {
    return directHeaders.get('retry-after');
  }
  if (directHeaders && typeof directHeaders === 'object') {
    return directHeaders['retry-after'];
  }

  const responseHeaders = candidate?.response?.headers;
  if (responseHeaders instanceof Headers) {
    return responseHeaders.get('retry-after');
  }
  if (responseHeaders && typeof responseHeaders === 'object') {
    return responseHeaders['retry-after'];
  }

  return undefined;
}

function getRateLimitDelayMs(error: unknown, attempt: number) {
  const retryAfterHeader = getRetryAfterHeader(error);
  const retryAfterSeconds = Number(retryAfterHeader);

  if (Number.isFinite(retryAfterSeconds) && retryAfterSeconds > 0) {
    return retryAfterSeconds * 1000;
  }

  const exponentialDelay = Math.min(
    AUTH_RATE_LIMIT_BASE_DELAY_MS * 2 ** Math.max(0, attempt - 1),
    AUTH_RATE_LIMIT_MAX_DELAY_MS,
  );
  const jitter = faker.number.int({ min: 250, max: 1250 });
  return exponentialDelay + jitter;
}

async function withRateLimitRetry<T>(label: string, work: () => Promise<T>) {
  let attempt = 0;

  while (true) {
    attempt += 1;

    try {
      return await work();
    } catch (error) {
      if (!isRateLimitError(error) || attempt > AUTH_RATE_LIMIT_MAX_RETRIES) {
        throw error;
      }

      const delayMs = getRateLimitDelayMs(error, attempt);
      logSeedProgress(
        `${label} hit Supabase auth rate limit on attempt ${attempt}/${AUTH_RATE_LIMIT_MAX_RETRIES}. Waiting ${Math.ceil(delayMs / 1000)}s before retrying.`,
      );
      await sleep(delayMs);
    }
  }
}

function buildAuthSeedInputs(options: SeedOptions, totalUsers: number) {
  return Array.from({ length: totalUsers }, () => {
    const firstName = faker.person.firstName();
    const lastName = faker.person.lastName();
    const name = `${firstName} ${lastName}`;
    const emailSlug = `${firstName}.${lastName}`.toLowerCase().replace(/[^a-z0-9]+/g, '.');
    const uniqueSuffix = faker.string.alphanumeric({ length: 4 }).toLowerCase();

    return {
      name,
      email: `${options.emailPrefix}.${emailSlug}.${uniqueSuffix}@zentry.dev`,
      gender: faker.helpers.arrayElement(['male', 'female', 'non-binary']),
    };
  });
}

export async function createAuthUsersForCount(options: SeedOptions, totalUsers: number) {
  const authService = new AuthService();
  const createdUsers: SeededAuthUser[] = [];
  const redirectTo = process.env.SUPABASE_AUTH_REDIRECT_URL || 'http://localhost:3000';
  const authSeedInputs = buildAuthSeedInputs(options, totalUsers);

  logSeedProgress(
    `Preparing Supabase auth users: total=${totalUsers}, batchSize=${AUTH_SIGNUP_BATCH_SIZE}, emailPrefix=${options.emailPrefix}`,
  );

  const authSeedBatches = chunkArray(authSeedInputs, AUTH_SIGNUP_BATCH_SIZE);

  for (const [batchIndex, authSeedBatch] of authSeedBatches.entries()) {
    logSeedProgress(
      `Creating auth batch ${batchIndex + 1}/${authSeedBatches.length} with ${authSeedBatch.length} users`,
    );
    const batchResults = await Promise.all(
      authSeedBatch.map(async ({ email, name, gender }) => {
        const signUpData = await withRateLimitRetry(`signUp ${email}`, () =>
          authService.signUpNewUser(email, options.password, redirectTo),
        );
        const sessionData = signUpData.session
          ? signUpData
          : await withRateLimitRetry(`signIn ${email}`, () => authService.signInWithEmail(email, options.password));

        if (!signUpData.user || !sessionData.session) {
          throw new Error(`Failed to create auth user for ${email}`);
        }

        return {
          authUserId: signUpData.user.id,
          email,
          password: options.password,
          name,
          gender,
          accessToken: sessionData.session.access_token,
          refreshToken: sessionData.session.refresh_token,
          expiresAt: new Date(new Date(0).setUTCSeconds(sessionData.session.expires_at ?? 0)).toISOString(),
          expiresIn: sessionData.session.expires_in,
        } satisfies SeededAuthUser;
      }),
    );

    createdUsers.push(...batchResults);
    logSeedProgress(`Finished auth batch ${batchIndex + 1}/${authSeedBatches.length}`);
  }

  return {
    createdUsers,
  };
}

export async function createAuthUsers(options: SeedOptions) {
  return createAuthUsersForCount(options, resolveRange(options.users));
}

export async function streamAuthUsers(
  options: SeedOptions,
  onBatch: (
    batchUsers: SeededAuthUser[],
    meta: { batchIndex: number; totalBatches: number; processedUsers: number },
  ) => Promise<void>,
) {
  const authService = new AuthService();
  const createdUsers: SeededAuthUser[] = [];
  const totalUsers = resolveRange(options.users);
  const redirectTo = process.env.SUPABASE_AUTH_REDIRECT_URL || 'http://localhost:3000';
  const authSeedInputs = buildAuthSeedInputs(options, totalUsers);

  logSeedProgress(
    `Preparing Supabase auth users: total=${totalUsers}, batchSize=${AUTH_SIGNUP_BATCH_SIZE}, emailPrefix=${options.emailPrefix}`,
  );

  const authSeedBatches = chunkArray(authSeedInputs, AUTH_SIGNUP_BATCH_SIZE);

  for (const [batchIndex, authSeedBatch] of authSeedBatches.entries()) {
    logSeedProgress(
      `Creating auth batch ${batchIndex + 1}/${authSeedBatches.length} with ${authSeedBatch.length} users`,
    );
    const batchResults = await Promise.all(
      authSeedBatch.map(async ({ email, name, gender }) => {
        const signUpData = await withRateLimitRetry(`signUp ${email}`, () =>
          authService.signUpNewUser(email, options.password, redirectTo),
        );
        const sessionData = signUpData.session
          ? signUpData
          : await withRateLimitRetry(`signIn ${email}`, () => authService.signInWithEmail(email, options.password));

        if (!signUpData.user || !sessionData.session) {
          throw new Error(`Failed to create auth user for ${email}`);
        }

        return {
          authUserId: signUpData.user.id,
          email,
          password: options.password,
          name,
          gender,
          accessToken: sessionData.session.access_token,
          refreshToken: sessionData.session.refresh_token,
          expiresAt: new Date(new Date(0).setUTCSeconds(sessionData.session.expires_at ?? 0)).toISOString(),
          expiresIn: sessionData.session.expires_in,
        } satisfies SeededAuthUser;
      }),
    );

    createdUsers.push(...batchResults);
    logSeedProgress(`Finished auth batch ${batchIndex + 1}/${authSeedBatches.length}`);
    await onBatch(batchResults, {
      batchIndex,
      totalBatches: authSeedBatches.length,
      processedUsers: createdUsers.length,
    });
  }

  return {
    createdUsers,
  };
}

export async function deleteAuthUsers(userIds: string[]) {
  if (userIds.length === 0) return;
  console.warn(
    `Database transaction rolled back, but ${userIds.length} Supabase auth users may still exist because the seeder is using non-admin auth signup.`,
  );
}
