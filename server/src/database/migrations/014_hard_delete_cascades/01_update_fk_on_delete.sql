ALTER TABLE "Users" DROP CONSTRAINT IF EXISTS "Users_mediaId_fkey";
ALTER TABLE "Media" DROP CONSTRAINT IF EXISTS "Media_uploader_fkey";
ALTER TABLE "Threads" DROP CONSTRAINT IF EXISTS "Threads_parentId_fkey";
ALTER TABLE "Threads" DROP CONSTRAINT IF EXISTS "Threads_eventId_fkey";
ALTER TABLE "Threads" DROP CONSTRAINT IF EXISTS "Threads_createdBy_fkey";
ALTER TABLE "Events" DROP CONSTRAINT IF EXISTS "Events_createdBy_fkey";
ALTER TABLE "Messages" DROP CONSTRAINT IF EXISTS "Messages_userId_fkey";
ALTER TABLE "Messages" DROP CONSTRAINT IF EXISTS "Messages_parentId_fkey";
ALTER TABLE "Messages" DROP CONSTRAINT IF EXISTS "Messages_threadId_fkey";
ALTER TABLE "Tags" DROP CONSTRAINT IF EXISTS "Tags_parentId_fkey";
ALTER TABLE "Tags" DROP CONSTRAINT IF EXISTS "Tags_createdBy_fkey";
ALTER TABLE "Activities" DROP CONSTRAINT IF EXISTS "Activities_actorId_fkey";
ALTER TABLE "Activities" DROP CONSTRAINT IF EXISTS "Activities_recipientId_fkey";
ALTER TABLE "UserAchievements" DROP CONSTRAINT IF EXISTS "UserAchievements_userId_fkey";
ALTER TABLE "AchievementProgress" DROP CONSTRAINT IF EXISTS "AchievementProgress_userId_fkey";
ALTER TABLE "Reactions" DROP CONSTRAINT IF EXISTS "Reactions_userId_fkey";
ALTER TABLE "EntityRatings" DROP CONSTRAINT IF EXISTS "EntityRatings_userId_fkey";
ALTER TABLE "SavedEntities" DROP CONSTRAINT IF EXISTS "SavedEntities_userId_fkey";

ALTER TABLE "Media"
ADD CONSTRAINT "Media_uploader_fkey"
FOREIGN KEY ("uploader") REFERENCES "Users"("id")
ON DELETE CASCADE;

ALTER TABLE "Users"
ADD CONSTRAINT "Users_mediaId_fkey"
FOREIGN KEY ("mediaId") REFERENCES "Media"("id")
ON DELETE SET NULL;

ALTER TABLE "Events"
ADD CONSTRAINT "Events_createdBy_fkey"
FOREIGN KEY ("createdBy") REFERENCES "Users"("id")
ON DELETE CASCADE;

ALTER TABLE "Threads"
ADD CONSTRAINT "Threads_parentId_fkey"
FOREIGN KEY ("parentId") REFERENCES "Threads"("id")
ON DELETE CASCADE;

ALTER TABLE "Threads"
ADD CONSTRAINT "Threads_eventId_fkey"
FOREIGN KEY ("eventId") REFERENCES "Events"("id")
ON DELETE CASCADE;

ALTER TABLE "Threads"
ADD CONSTRAINT "Threads_createdBy_fkey"
FOREIGN KEY ("createdBy") REFERENCES "Users"("id")
ON DELETE CASCADE;

ALTER TABLE "Messages"
ADD CONSTRAINT "Messages_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "Users"("id")
ON DELETE CASCADE;

ALTER TABLE "Messages"
ADD CONSTRAINT "Messages_parentId_fkey"
FOREIGN KEY ("parentId") REFERENCES "Messages"("id")
ON DELETE CASCADE;

ALTER TABLE "Messages"
ADD CONSTRAINT "Messages_threadId_fkey"
FOREIGN KEY ("threadId") REFERENCES "Threads"("id")
ON DELETE CASCADE;

ALTER TABLE "Tags"
ADD CONSTRAINT "Tags_parentId_fkey"
FOREIGN KEY ("parentId") REFERENCES "Tags"("id")
ON DELETE CASCADE;

ALTER TABLE "Tags"
ADD CONSTRAINT "Tags_createdBy_fkey"
FOREIGN KEY ("createdBy") REFERENCES "Users"("id")
ON DELETE CASCADE;

ALTER TABLE "Activities"
ADD CONSTRAINT "Activities_actorId_fkey"
FOREIGN KEY ("actorId") REFERENCES "Users"("id")
ON DELETE CASCADE;

ALTER TABLE "Activities"
ADD CONSTRAINT "Activities_recipientId_fkey"
FOREIGN KEY ("recipientId") REFERENCES "Users"("id")
ON DELETE CASCADE;

ALTER TABLE "UserAchievements"
ADD CONSTRAINT "UserAchievements_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "Users"("id")
ON DELETE CASCADE;

ALTER TABLE "AchievementProgress"
ADD CONSTRAINT "AchievementProgress_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "Users"("id")
ON DELETE CASCADE;

ALTER TABLE "Reactions"
ADD CONSTRAINT "Reactions_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "Users"("id")
ON DELETE CASCADE;

ALTER TABLE "EntityRatings"
ADD CONSTRAINT "EntityRatings_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "Users"("id")
ON DELETE CASCADE;

ALTER TABLE "SavedEntities"
ADD CONSTRAINT "SavedEntities_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "Users"("id")
ON DELETE CASCADE;
