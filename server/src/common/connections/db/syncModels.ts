import { QueryTypes } from 'sequelize';
import { Activity } from '@/src/features/activity/model';
import { Address } from '@/src/features/addresses/model';
import { AchievementProgress, UserAchievement } from '@/src/features/achievements/model';
import { EntityEngagement, EntityRating } from '@/src/features/engagement/model';
import { Event } from '@/src/features/events/model';
import { Media } from '@/src/features/media/model';
import { MEDIA_TABLE_NAME } from '@/src/features/media/constants';
import { Message } from '@/src/features/messages/model';
import { Reaction } from '@/src/features/reactions/model';
import { SavedEntity } from '@/src/features/saves/model';
import { SearchResult } from '@/src/features/search/model';
import { Tag } from '@/src/features/tags/model';
import { Thread } from '@/src/features/threads/model';
import { USER_TABLE_NAME } from '@/src/features/users/constants';
import { User } from '@/src/features/users/model';

const REGISTERED_MODELS = [
  SearchResult,
  Address,
  User,
  Media,
  Tag,
  Event,
  Thread,
  Message,
  Reaction,
  EntityEngagement,
  EntityRating,
  SavedEntity,
  Activity,
  UserAchievement,
  AchievementProgress,
] as const;

async function hasConstraint(constraintName: string) {
  const { sequelize } = User;
  if (!sequelize) {
    throw new Error('User model is not attached to a Sequelize instance.');
  }
  const rows = await sequelize.query<{ exists: boolean }>(
    `
      SELECT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = :constraintName
      ) AS "exists"
    `,
    {
      replacements: { constraintName },
      type: QueryTypes.SELECT,
    },
  );

  return rows[0]?.exists === true;
}

async function ensureCircularForeignKeys() {
  const { sequelize } = User;
  if (!sequelize) {
    throw new Error('User model is not attached to a Sequelize instance.');
  }

  if (!(await hasConstraint('Media_uploader_fkey'))) {
    await sequelize.query(
      `ALTER TABLE "${MEDIA_TABLE_NAME}" ADD CONSTRAINT "Media_uploader_fkey" FOREIGN KEY ("uploader") REFERENCES "${USER_TABLE_NAME}"("id") ON DELETE CASCADE`,
    );
  }

  if (!(await hasConstraint('Users_mediaId_fkey'))) {
    await sequelize.query(
      `ALTER TABLE "${USER_TABLE_NAME}" ADD CONSTRAINT "Users_mediaId_fkey" FOREIGN KEY ("mediaId") REFERENCES "${MEDIA_TABLE_NAME}"("id") ON DELETE SET NULL`,
    );
  }
}

export async function syncRegisteredModels() {
  for (const model of REGISTERED_MODELS) {
    await model.sync({ alter: false });
  }

  await ensureCircularForeignKeys();
}
