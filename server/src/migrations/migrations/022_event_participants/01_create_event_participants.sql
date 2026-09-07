-- Replaces the "Events"."participants" / "Events"."verifiers" JSONB arrays with
-- one row per (event, user). Verification is an attribute of participation:
-- a verifier is a participant whose "verifiedAt" is set.
--
-- The JSONB columns stay in place; a later migration drops them once every
-- read path has moved over.
--
-- The enum is named the way Sequelize's DataTypes.ENUM names it
-- (enum_<Table>_<column>), because syncRegisteredModels may have already
-- created this table from the model before this migration runs. Both paths have
-- to converge on one type name or the backfill below cannot cast to it.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'enum_EventParticipants_status'
    ) THEN
        CREATE TYPE "enum_EventParticipants_status" AS ENUM ('pending', 'confirmed', 'declined');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS "EventParticipants" (
    "id"          UUID        PRIMARY KEY DEFAULT uuidv7(),
    "eventId"     UUID        NOT NULL REFERENCES "Events"("id") ON DELETE CASCADE,
    "userId"      UUID        NOT NULL REFERENCES "Users"("id") ON DELETE CASCADE,
    "status"      "enum_EventParticipants_status" NOT NULL DEFAULT 'pending',
    "verifiedAt"  TIMESTAMPTZ NULL,
    "verifiedLat" DOUBLE PRECISION NULL,
    "verifiedLng" DOUBLE PRECISION NULL,
    "invitedBy"   UUID        NULL REFERENCES "Users"("id") ON DELETE SET NULL,
    "createdAt"   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt"   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Makes join idempotent via ON CONFLICT and kills the duplicate-participant class of bug.
CREATE UNIQUE INDEX IF NOT EXISTS "event_participants_eventId_userId_idx"
ON "EventParticipants"("eventId", "userId");

-- "events I am part of" lookups, and the private-event visibility EXISTS check.
CREATE INDEX IF NOT EXISTS "event_participants_userId_idx"
ON "EventParticipants"("userId");

-- Verifier lists and verifierCount only ever want the verified rows.
CREATE INDEX IF NOT EXISTS "event_participants_eventId_verifiedAt_idx"
ON "EventParticipants"("eventId", "verifiedAt")
WHERE "verifiedAt" IS NOT NULL;

-- When syncRegisteredModels created this table first, it left "id" and the
-- timestamps without database defaults — Sequelize fills those in from JS. The
-- backfill below is plain SQL, and a rollback-and-rerun on a fresh database
-- should not produce a different schema, so pin the defaults either way.
ALTER TABLE "EventParticipants" ALTER COLUMN "id" SET DEFAULT uuidv7();
ALTER TABLE "EventParticipants" ALTER COLUMN "createdAt" SET DEFAULT NOW();
ALTER TABLE "EventParticipants" ALTER COLUMN "updatedAt" SET DEFAULT NOW();
