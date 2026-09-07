-- Enums
CREATE TYPE "AccessLevel" AS ENUM ('public', 'private', 'restricted');
CREATE TYPE "MediaType" AS ENUM ('image', 'video', 'audio', 'document');
CREATE TYPE "EventType" AS ENUM ('organized', 'custom');
CREATE TYPE "ActivityVisibility" AS ENUM ('public', 'private');
CREATE TYPE "ActivityEntityType" AS ENUM ('event', 'message', 'thread', 'reaction', 'achievement', 'user', 'system');

-- Media Table
CREATE TABLE "Media" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "type" "MediaType" NOT NULL,
    "url" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "caption" TEXT NULL,
    "thumbnail" TEXT NULL,
    "size" INTEGER NULL,
    "mimeType" TEXT NULL,
    "duration" INTEGER NULL,
    "uploader" UUID NOT NULL, -- Foreign key will be added later
    "storage" JSONB NOT NULL,
    "access" "AccessLevel" NOT NULL,
    "metadata" JSONB NOT NULL DEFAULT '{}'::JSONB,
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL -- Soft delete column
);

COMMENT ON COLUMN "Media"."storage" IS '{
"provider": "local | s3 | gcs | cloudinary | supabase", -- Media provider
"path": "string", -- Path to the file in the storage provider
"metadata": "Record<string, any>" -- Additional metadata (key-value pairs)
}';

-- User Table
CREATE TABLE "Users" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL UNIQUE,
    "gender" TEXT NOT NULL,
    "address" JSONB,
    "isVerified" BOOLEAN NOT NULL DEFAULT FALSE,
    "profilePic" JSONB NULL,
    "mediaId" UUID NULL, -- Foreign key will be added later
    "bio" TEXT NULL,
    "username" TEXT NULL,
    "password" TEXT NULL,
    "meta" JSONB NOT NULL DEFAULT '{}'::JSONB,
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL -- Soft delete column
);

-- Add foreign key constraints for User and Media after both tables are created
ALTER TABLE "Media" ADD CONSTRAINT "Media_uploader_fkey" FOREIGN KEY ("uploader") REFERENCES "Users"("id") ON DELETE CASCADE;
ALTER TABLE "Users" ADD CONSTRAINT "Users_mediaId_fkey" FOREIGN KEY ("mediaId") REFERENCES "Media"("id") ON DELETE SET NULL;

-- Thread Table
CREATE TABLE "Threads" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "visibility" "AccessLevel" NOT NULL,
    "parentId" UUID NULL REFERENCES "Threads"("id") ON DELETE CASCADE,
    "eventId" UUID, -- Foreign key will be added later
    "lockHistory" JSONB NOT NULL DEFAULT '[]'::JSONB,
    "stats" JSONB NOT NULL DEFAULT '{}'::JSONB,
    "createdBy" UUID NULL REFERENCES "Users"("id") ON DELETE CASCADE,
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL -- Soft delete column
);

COMMENT ON COLUMN "Threads"."lockHistory" IS '{
 "lockedBy": "string", -- ID of the user who locked the thread
 "lockedAt": "string" -- Timestamp of when the thread was locked
}[]';

-- Event Table
CREATE TABLE "Events" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "location" JSONB NOT NULL,
    "participants" JSONB NOT NULL DEFAULT '[]'::JSONB,
    "verifiers" JSONB NOT NULL DEFAULT '[]'::JSONB,
    "type" "EventType" NOT NULL,
    "createdBy" UUID NOT NULL REFERENCES "Users"("id") ON DELETE CASCADE,
    "isDraft" BOOLEAN NOT NULL DEFAULT FALSE,
    "cancelledAt" TIMESTAMPTZ NULL,
    "capacity" INTEGER NULL,
    "tags" JSONB NOT NULL DEFAULT '[]'::JSONB,
    "media" JSONB NOT NULL DEFAULT '[]'::JSONB,
    "stats" JSONB NOT NULL DEFAULT '{}'::JSONB,
    "startTime" TIMESTAMPTZ NOT NULL,
    "endTime" TIMESTAMPTZ NOT NULL,
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL -- Soft delete column
);

COMMENT ON COLUMN "Events"."location" IS '{
"address": "string",
"coordinates": {
"latitude": "number",
"longitude": "number"
},
"venue": "string | null",
"latitude": "number | null",
"longitude": "number | null"
}';

COMMENT ON COLUMN "Events"."participants" IS '{
"userId": "string",
"status": "confirmed | pending | declined"
}[]';

-- Add foreign key constraint for Thread after both tables are created
ALTER TABLE "Threads" ADD CONSTRAINT "Threads_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Events"("id") ON DELETE CASCADE;

-- Message Table
CREATE TABLE "Messages" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "userId" UUID NOT NULL REFERENCES "Users"("id") ON DELETE CASCADE,
    "parentId" UUID NULL REFERENCES "Messages"("id") ON DELETE CASCADE,
    "content" JSONB NOT NULL, -- Unified field for text or richObject
    "isEdited" BOOLEAN NOT NULL DEFAULT FALSE,
    "stats" JSONB NOT NULL DEFAULT '{}'::JSONB,
    "threadId" UUID NOT NULL REFERENCES "Threads"("id") ON DELETE CASCADE,
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL -- Soft delete column
);

COMMENT ON COLUMN "Messages"."content" IS '{
"text": "string", -- Always present (for plain text or as optional caption)
"media": "string[] | null", -- Optional array of media ids
"links": {
"url": "string",
"title": "string"
}[] | null -- Optional array of links with titles
}';

-- Tag Table
CREATE TABLE "Tags" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "name" TEXT NOT NULL,
    "value" TEXT NOT NULL UNIQUE,
    "description" TEXT NULL,
    "icon" TEXT NULL,
    "color" TEXT NULL,
    "parentId" UUID NULL REFERENCES "Tags"("id") ON DELETE CASCADE,
    "createdBy" UUID NULL REFERENCES "Users"("id") ON DELETE CASCADE,
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL -- Soft delete column
);

-- Activity Table
CREATE TABLE "Activities" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "actorId" UUID NOT NULL REFERENCES "Users"("id") ON DELETE CASCADE,
    "recipientId" UUID NULL REFERENCES "Users"("id") ON DELETE CASCADE,
    "type" TEXT NOT NULL,
    "entityType" "ActivityEntityType" NOT NULL,
    "entityId" TEXT NOT NULL,
    "payload" JSONB NOT NULL DEFAULT '{}'::JSONB,
    "visibility" "ActivityVisibility" NOT NULL DEFAULT 'public',
    "readAt" TIMESTAMPTZ NULL,
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL
);

CREATE INDEX "activities_actorId_createdAt_idx" ON "Activities"("actorId", "createdAt");
CREATE INDEX "activities_actorId_updatedAt_idx" ON "Activities"("actorId", "updatedAt");
CREATE INDEX "activities_recipientId_createdAt_idx" ON "Activities"("recipientId", "createdAt");
CREATE INDEX "activities_recipientId_updatedAt_idx" ON "Activities"("recipientId", "updatedAt");
CREATE INDEX "activities_entityType_entityId_idx" ON "Activities"("entityType", "entityId");
CREATE INDEX "activities_type_idx" ON "Activities"("type");
CREATE INDEX "activities_updatedAt_idx" ON "Activities"("updatedAt");

-- User achievements and progress
CREATE TABLE "UserAchievements" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "userId" UUID NOT NULL REFERENCES "Users"("id") ON DELETE CASCADE,
    "key" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "icon" TEXT NULL,
    "metadata" JSONB NOT NULL DEFAULT '{}'::JSONB,
    "unlockedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL,
    UNIQUE ("userId", "key")
);

CREATE INDEX "user_achievements_userId_unlockedAt_idx" ON "UserAchievements"("userId", "unlockedAt");

CREATE TABLE "AchievementProgress" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "userId" UUID NOT NULL UNIQUE REFERENCES "Users"("id") ON DELETE CASCADE,
    "metrics" JSONB NOT NULL DEFAULT '{}'::JSONB,
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL
);

-- Reactions
CREATE TABLE "Reactions" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "contentId" TEXT NOT NULL,
    "emoji" TEXT NOT NULL,
    "userId" UUID NOT NULL REFERENCES "Users"("id") ON DELETE CASCADE,
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL
);

CREATE INDEX "reactions_contentId_idx" ON "Reactions"("contentId");
CREATE INDEX "users_updatedAt_idx" ON "Users"("updatedAt");
CREATE INDEX "threads_updatedAt_idx" ON "Threads"("updatedAt");
CREATE INDEX "events_updatedAt_idx" ON "Events"("updatedAt");
CREATE INDEX "events_startTime_idx" ON "Events"("startTime");
CREATE INDEX "events_endTime_idx" ON "Events"("endTime");
CREATE INDEX "events_isDraft_idx" ON "Events"("isDraft");
CREATE INDEX "events_cancelledAt_idx" ON "Events"("cancelledAt");
CREATE INDEX "events_active_startTime_idx" ON "Events"("startTime") WHERE "cancelledAt" IS NULL AND "isDraft" = FALSE;
CREATE INDEX "events_active_endTime_idx" ON "Events"("endTime") WHERE "cancelledAt" IS NULL AND "isDraft" = FALSE;
CREATE INDEX "messages_updatedAt_idx" ON "Messages"("updatedAt");
CREATE INDEX "tags_updatedAt_idx" ON "Tags"("updatedAt");
CREATE INDEX "tags_parentId_idx" ON "Tags"("parentId");

-- Search results
CREATE TYPE "enum_SearchResults_type" AS ENUM ('event', 'user', 'tag');

CREATE TABLE "SearchResults" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "type" "enum_SearchResults_type" NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NULL,
    "imageUrl" TEXT NULL,
    "metadata" JSONB NOT NULL DEFAULT '{}'::JSONB,
    "relevanceScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL
);

CREATE INDEX "events_location_gix" ON "Events" USING GIST (
  ST_SetSRID(
    ST_MakePoint(
      CAST(COALESCE("location"->'coordinates'->>'longitude', "location"->>'longitude') AS DOUBLE PRECISION),
      CAST(COALESCE("location"->'coordinates'->>'latitude', "location"->>'latitude') AS DOUBLE PRECISION)
    ),
    4326
  )
);

CREATE INDEX "users_address_gix" ON "Users" USING GIST (
  ST_SetSRID(
    ST_MakePoint(
      CAST("address"->'coordinates'->>'longitude' AS DOUBLE PRECISION),
      CAST("address"->'coordinates'->>'latitude' AS DOUBLE PRECISION)
    ),
    4326
  )
);
