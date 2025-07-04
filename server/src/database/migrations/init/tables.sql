-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- Enable PostGIS for spatial functions
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enums
CREATE TYPE "ThreadType" AS ENUM ('discussion', 'qna');
CREATE TYPE "AccessLevel" AS ENUM ('public', 'private', 'restricted');
CREATE TYPE "MediaType" AS ENUM ('image', 'video', 'audio', 'document');
CREATE TYPE "EventType" AS ENUM ('organized', 'custom');
CREATE TYPE "EventStatus" AS ENUM ('draft', 'upcoming', 'ongoing', 'completed', 'cancelled');

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
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL -- Soft delete column
);

-- Add foreign key constraints for User and Media after both tables are created
ALTER TABLE "Media" ADD CONSTRAINT "Media_uploader_fkey" FOREIGN KEY ("uploader") REFERENCES "Users"("id");
ALTER TABLE "Users" ADD CONSTRAINT "Users_mediaId_fkey" FOREIGN KEY ("mediaId") REFERENCES "Media"("id");

-- Thread Table
CREATE TABLE "Threads" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "type" "ThreadType" NOT NULL,
    "status" "AccessLevel" NOT NULL,
    "visibility" "AccessLevel" NOT NULL,
    "eventId" UUID, -- Foreign key will be added later
    "lockHistory" JSONB DEFAULT '{}'::JSONB,
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL -- Soft delete column
);

COMMENT ON COLUMN "Threads"."lockHistory" IS '{
"lockedBy": "string", -- ID of the user who locked the thread
"lockedAt": "string" -- Timestamp of when the thread was locked
}';

-- Event Table
CREATE TABLE "Events" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "location" JSONB NOT NULL,
    "participants" JSONB NOT NULL DEFAULT '[]'::JSONB,
    "verifiers" JSONB NOT NULL DEFAULT '[]'::JSONB,
    "type" "EventType" NOT NULL,
    "createdBy" UUID NOT NULL REFERENCES "Users"("id"),
    "status" "EventStatus" NOT NULL,
    "capacity" INTEGER NOT NULL,
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
"venue": "string | null"
}';

COMMENT ON COLUMN "Events"."participants" IS '{
"userId": "string",
"status": "confirmed | pending | declined"
}[]';

-- Add foreign key constraint for Thread after both tables are created
ALTER TABLE "Threads" ADD CONSTRAINT "Threads_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Events"("id");

-- Message Table
CREATE TABLE "Messages" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "userId" UUID NOT NULL REFERENCES "Users"("id"),
    "parentId" UUID NULL REFERENCES "Messages"("id"),
    "content" JSONB NOT NULL, -- Unified field for text or richObject
    "isEdited" BOOLEAN NOT NULL DEFAULT FALSE,
    "threadId" UUID NOT NULL REFERENCES "Threads"("id"),
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
    "parentId" UUID NULL REFERENCES "Tags"("id"),
    "createdBy" UUID NULL REFERENCES "Users"("id"),
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL -- Soft delete column
);

-- Junction Table: Event-Tags
CREATE TABLE "EventTags" (
    "eventId" UUID NOT NULL REFERENCES "Events"("id") ON DELETE CASCADE,
    "tagId" UUID NOT NULL REFERENCES "Tags"("id") ON DELETE CASCADE,
    PRIMARY KEY ("eventId", "tagId"),
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL -- Soft delete column
);

COMMENT ON TABLE "EventTags" IS 'Junction table for many-to-many relationship between Events and Tags';
COMMENT ON COLUMN "EventTags"."eventId" IS 'ID of the event';
COMMENT ON COLUMN "EventTags"."tagId" IS 'ID of the tag';

-- Junction Table: Event-Media
CREATE TABLE "EventMedia" (
    "eventId" UUID NOT NULL REFERENCES "Events"("id") ON DELETE CASCADE,
    "mediaId" UUID NOT NULL REFERENCES "Media"("id") ON DELETE CASCADE,
    PRIMARY KEY ("eventId", "mediaId"),
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL -- Soft delete column
);

COMMENT ON TABLE "EventMedia" IS 'Junction table for many-to-many relationship between Events and Media';
COMMENT ON COLUMN "EventMedia"."eventId" IS 'ID of the event';
COMMENT ON COLUMN "EventMedia"."mediaId" IS 'ID of the media';
