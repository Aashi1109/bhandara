import { QueryTypes } from 'sequelize';
import { Activity } from '@/features/activity/model';
import { Address } from '@/features/addresses/model';
import { AchievementProgress, UserAchievement } from '@/features/achievements/model';
import { EntityEngagement, EntityRating } from '@/features/engagement/model';
import { Event, EventParticipant } from '@/features/events/model';
import { Media } from '@/features/media/model';
import { MEDIA_TABLE_NAME } from '@/features/media/constants';
import { Message } from '@/features/messages/model';
import { Reaction } from '@/features/reactions/model';
import { SavedEntity } from '@/features/saves/model';
import { SearchResult } from '@/features/search/model';
import { Tag } from '@/features/tags/model';
import { Thread } from '@/features/threads/model';
import { USER_TABLE_NAME } from '@/features/users/constants';
import { User } from '@/features/users/model';
import { UserSettings } from '@/features/users/settings.model';

const REGISTERED_MODELS = [
  SearchResult,
  Address,
  User,
  UserSettings,
  Media,
  Tag,
  Event,
  EventParticipant,
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
