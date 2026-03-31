-- Remove soft-delete columns from all tables.
-- With paranoid mode disabled, Sequelize no longer manages these columns
-- and .destroy() performs a real DELETE.

ALTER TABLE "Media" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "Users" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "Threads" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "Events" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "Messages" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "Tags" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "Activities" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "UserAchievements" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "AchievementProgress" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "Reactions" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "SearchResults" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "EntityEngagements" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "EntityRatings" DROP COLUMN IF EXISTS "deletedAt";
ALTER TABLE "SavedEntities" DROP COLUMN IF EXISTS "deletedAt";
