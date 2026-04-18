import fs from 'fs';
import os from 'os';
import path from 'path';
import { fork, type ChildProcess } from 'child_process';
import { seedContentForUsers } from './content';
import type { SeedCoordinatorUser, SeedOptions, SeederWorkerPayload } from './types';
import { computeWorkerCount, formatSeedStep, logSeedProgress } from './utils';
import { getDBConnection } from '@/src/common/connections/db';

function resolveWorkerModulePath() {
  const tsPath = path.resolve(__dirname, 'worker.ts');
  if (fs.existsSync(tsPath)) return { workerPath: tsPath, isTypeScript: true };

  const jsPath = path.resolve(__dirname, 'worker.js');
  return { workerPath: jsPath, isTypeScript: false };
}

function createWorkerProcess(): ChildProcess {
  const { workerPath, isTypeScript } = resolveWorkerModulePath();
  const execArgv = isTypeScript ? ['-r', 'tsx/cjs', '-r', 'tsconfig-paths/register'] : [];
  const workerEnv = {
    ...process.env,
    DB_POOL_MAX: process.env.SEED_DB_POOL_MAX || process.env.DB_POOL_MAX || '1',
    DB_POOL_MIN: process.env.SEED_DB_POOL_MIN || process.env.DB_POOL_MIN || '0',
    DB_POOL_ACQUIRE_MS: process.env.SEED_DB_POOL_ACQUIRE_MS || process.env.DB_POOL_ACQUIRE_MS || '120000',
    DB_POOL_IDLE_MS: process.env.SEED_DB_POOL_IDLE_MS || process.env.DB_POOL_IDLE_MS || '10000',
  };

  return fork(workerPath, [], {
    cwd: process.cwd(),
    env: workerEnv,
    execArgv,
    stdio: ['inherit', 'inherit', 'inherit', 'ipc'],
  });
}

function getWorkerRetryConfig() {
  const baseDelayMs = Number(process.env.SEED_WORKER_RETRY_DELAY_MS || 5000);
  const maxDelayMs = Number(process.env.SEED_WORKER_RETRY_MAX_DELAY_MS || 60000);
  const maxRetries = Number(process.env.SEED_WORKER_MAX_RETRIES || 0);

  return {
    baseDelayMs: Number.isFinite(baseDelayMs) ? baseDelayMs : 5000,
    maxDelayMs: Number.isFinite(maxDelayMs) ? maxDelayMs : 60000,
    maxRetries: Number.isFinite(maxRetries) ? maxRetries : 0,
  };
}

function wait(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function runWorkerShard(payload: SeederWorkerPayload) {
  const { baseDelayMs, maxDelayMs, maxRetries } = getWorkerRetryConfig();
  let attempt = 0;

  while (true) {
    const child = createWorkerProcess();

    try {
      const result = await new Promise<Awaited<ReturnType<typeof seedContentForUsers>>>((resolve, reject) => {
        const cleanup = () => {
          child.removeAllListeners('message');
          child.removeAllListeners('exit');
          child.removeAllListeners('error');
        };

        child.on('message', (message: any) => {
          if (message?.type === 'result') {
            cleanup();
            resolve(message.result);
            child.disconnect();
            return;
          }

          if (message?.type === 'error') {
            cleanup();
            reject({
              retryable: Boolean(message.error?.retryable),
              message: message.error?.message || `Worker ${payload.workerIndex + 1} failed`,
            });
            child.disconnect();
          }
        });

        child.on('error', (error) => {
          cleanup();
          reject({
            retryable: true,
            message: error instanceof Error ? error.message : String(error),
          });
        });

        child.on('exit', (code) => {
          if (code && code !== 0) {
            cleanup();
            reject({
              retryable: true,
              message: `Worker ${payload.workerIndex + 1} exited with code ${code}`,
            });
          }
        });

        child.send({ type: 'run', payload });
      });

      return result;
    } catch (error: any) {
      if (!child.killed) {
        child.kill('SIGTERM');
      }

      const retryable = Boolean(error?.retryable);
      if (!retryable) {
        throw new Error(error?.message || `Worker ${payload.workerIndex + 1} failed`, { cause: error });
      }

      attempt += 1;
      if (maxRetries > 0 && attempt > maxRetries) {
        throw new Error(error?.message || `Worker ${payload.workerIndex + 1} exhausted retries`, { cause: error });
      }

      const delayMs = Math.min(baseDelayMs * 2 ** Math.max(0, attempt - 1), maxDelayMs);
      logSeedProgress(
        formatSeedStep(
          `worker=${payload.workerIndex + 1}/${payload.totalWorkers}`,
          'retry',
          `attempt=${attempt} delayMs=${delayMs} reason=${error?.message || 'unknown'}`,
        ),
      );
      await wait(delayMs);
    }
  }
}

async function runUsersWithWorkerConcurrency({
  workerCount,
  allUsers,
  options,
  tagIds,
}: {
  workerCount: number;
  allUsers: SeedCoordinatorUser[];
  options: SeedOptions;
  tagIds: string[];
}) {
  const results: Array<Awaited<ReturnType<typeof seedContentForUsers>>> = [];
  let nextUserIndex = 0;

  await Promise.all(
    Array.from({ length: Math.min(workerCount, allUsers.length) }, async (_, workerSlot) => {
      while (true) {
        const currentIndex = nextUserIndex;
        nextUserIndex += 1;

        if (currentIndex >= allUsers.length) {
          return;
        }

        const user = allUsers[currentIndex];
        const result = await runWorkerShard({
          options,
          assignedUsers: [user],
          allUsers,
          tagIds,
          workerIndex: workerSlot,
          totalWorkers: workerCount,
        });
        results.push(result);
      }
    }),
  );

  return results;
}

export async function runSeedWorkers({
  options,
  allUsers,
  tagIds,
}: {
  options: SeedOptions;
  allUsers: SeedCoordinatorUser[];
  tagIds: string[];
}) {
  const cpuCount = typeof os.availableParallelism === 'function' ? os.availableParallelism() : os.cpus().length;
  const envWorkerCount = Number(process.env.SEED_WORKERS || 0);
  const requestedWorkers = options.seedWorkers ?? (envWorkerCount > 0 ? envWorkerCount : undefined);
  const workerCount = computeWorkerCount(requestedWorkers, allUsers.length, cpuCount);

  if (workerCount <= 1) {
    logSeedProgress(formatSeedStep('coordinator', 'workers', `mode=single users=${allUsers.length}`));
    const sequelize = getDBConnection()!;
    return [
      await seedContentForUsers({
        sequelize,
        assignedUsers: allUsers,
        allUsers,
        tagIds,
        options,
        shardLabel: 'worker=1/1',
      }),
    ];
  }

  logSeedProgress(
    formatSeedStep('coordinator', 'workers', `mode=parallel workers=${workerCount} userTasks=${allUsers.length}`),
  );
  return runUsersWithWorkerConcurrency({
    workerCount,
    allUsers,
    options,
    tagIds,
  });
}
