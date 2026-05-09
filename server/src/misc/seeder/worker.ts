import dotenv from 'dotenv';
import { disconnect, getDBConnection } from '@/common/connections/db';
import { seedContentForUsers } from './content';
import type { SeederWorkerPayload } from './types';
import { formatSeedStep, isTransientDatabaseError, logSeedProgress } from './utils';

dotenv.config();

type WorkerMessage =
  | { type: 'run'; payload: SeederWorkerPayload }
  | { type: 'result'; result: Awaited<ReturnType<typeof seedContentForUsers>> }
  | { type: 'error'; error: { message: string; stack?: string; retryable?: boolean } };

process.on('message', async (message: WorkerMessage) => {
  if (message.type !== 'run') return;

  const sequelize = getDBConnection()!;
  const shardLabel = `worker=${message.payload.workerIndex + 1}/${message.payload.totalWorkers}`;

  try {
    logSeedProgress(
      formatSeedStep(shardLabel, 'process', `start assignedUsers=${message.payload.assignedUsers.length}`),
    );
    const result = await seedContentForUsers({
      sequelize,
      assignedUsers: message.payload.assignedUsers,
      allUsers: message.payload.allUsers,
      tagIds: message.payload.tagIds,
      options: message.payload.options,
      shardLabel,
    });

    if (process.send) {
      process.send({ type: 'result', result } satisfies WorkerMessage);
    }
  } catch (error) {
    if (process.send) {
      process.send({
        type: 'error',
        error: {
          message: error instanceof Error ? error.message : String(error),
          stack: error instanceof Error ? error.stack : undefined,
          retryable: isTransientDatabaseError(error),
        },
      } satisfies WorkerMessage);
    }
    process.exitCode = 1;
  } finally {
    await disconnect();
  }
});
