DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'SavedEntityType'
    ) THEN
        CREATE TYPE "SavedEntityType" AS ENUM ('event', 'thread', 'message');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS "SavedEntities" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "userId" UUID NOT NULL REFERENCES "Users"("id"),
    "entityType" "SavedEntityType" NOT NULL,
    "entityId" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS "saved_entities_userId_entityType_entityId_idx"
ON "SavedEntities"("userId", "entityType", "entityId");

CREATE INDEX IF NOT EXISTS "saved_entities_userId_updatedAt_idx"
ON "SavedEntities"("userId", "updatedAt");

CREATE INDEX IF NOT EXISTS "saved_entities_entityType_entityId_idx"
ON "SavedEntities"("entityType", "entityId");
