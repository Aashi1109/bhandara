CREATE TABLE IF NOT EXISTS "EntityEngagements" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "stats" JSONB NOT NULL DEFAULT '{}'::JSONB,
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS "entity_engagements_entityType_entityId_idx"
ON "EntityEngagements"("entityType", "entityId");

CREATE INDEX IF NOT EXISTS "entity_engagements_updatedAt_idx"
ON "EntityEngagements"("updatedAt");

CREATE TABLE IF NOT EXISTS "EntityRatings" (
    "id" UUID PRIMARY KEY DEFAULT uuidv7(),
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "userId" UUID NOT NULL REFERENCES "Users"("id"),
    "value" INTEGER NOT NULL CHECK ("value" BETWEEN 1 AND 5),
    "createdAt" TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt" TIMESTAMPTZ NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS "entity_ratings_entityType_entityId_userId_idx"
ON "EntityRatings"("entityType", "entityId", "userId");

CREATE INDEX IF NOT EXISTS "entity_ratings_entityType_entityId_idx"
ON "EntityRatings"("entityType", "entityId");

CREATE INDEX IF NOT EXISTS "entity_ratings_userId_updatedAt_idx"
ON "EntityRatings"("userId", "updatedAt");
