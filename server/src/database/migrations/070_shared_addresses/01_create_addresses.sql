DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'AddressEntityType'
  ) THEN
    CREATE TYPE "AddressEntityType" AS ENUM ('user', 'event');
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS "Addresses" (
  "id" UUID PRIMARY KEY DEFAULT uuidv7(),
  "entityType" "AddressEntityType" NOT NULL,
  "entityId" UUID NOT NULL,
  "address" TEXT NULL,
  "latitude" DOUBLE PRECISION NULL,
  "longitude" DOUBLE PRECISION NULL,
  "metadata" JSONB NOT NULL DEFAULT '{}'::JSONB,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE "Addresses"
  ADD COLUMN IF NOT EXISTS "entityType" "AddressEntityType",
  ADD COLUMN IF NOT EXISTS "entityId" UUID,
  ADD COLUMN IF NOT EXISTS "address" TEXT,
  ADD COLUMN IF NOT EXISTS "latitude" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "longitude" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "metadata" JSONB NOT NULL DEFAULT '{}'::JSONB,
  ADD COLUMN IF NOT EXISTS "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE UNIQUE INDEX IF NOT EXISTS "addresses_entityType_entityId_key" ON "Addresses" ("entityType", "entityId");

CREATE INDEX IF NOT EXISTS "addresses_coords_gix" ON "Addresses" USING GIST (
  ST_SetSRID(
    ST_MakePoint("longitude", "latitude"),
    4326
  )
);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'Users'
      AND column_name = 'address'
  ) THEN
    INSERT INTO "Addresses" (
      "id",
      "entityType",
      "entityId",
      "address",
      "latitude",
      "longitude",
      "metadata",
      "createdAt",
      "updatedAt"
    )
    SELECT
      uuidv7(),
      'user',
      "id",
      CASE
        WHEN jsonb_typeof("address") = 'object' AND jsonb_typeof("address"->'address') = 'string'
          THEN "address"->>'address'
        ELSE NULL
      END,
      CASE
        WHEN jsonb_typeof("address") = 'object'
          THEN COALESCE(
            NULLIF("address"->>'latitude', '')::DOUBLE PRECISION,
            NULLIF("address"->'coordinates'->>'latitude', '')::DOUBLE PRECISION
          )
        ELSE NULL
      END,
      CASE
        WHEN jsonb_typeof("address") = 'object'
          THEN COALESCE(
            NULLIF("address"->>'longitude', '')::DOUBLE PRECISION,
            NULLIF("address"->'coordinates'->>'longitude', '')::DOUBLE PRECISION
          )
        ELSE NULL
      END,
      CASE
        WHEN jsonb_typeof("address") = 'object'
          THEN "address" - 'address' - 'latitude' - 'longitude' - 'coordinates'
        ELSE '{}'::JSONB
      END,
      "createdAt",
      "updatedAt"
    FROM "Users"
    WHERE "address" IS NOT NULL
    ON CONFLICT ("entityType", "entityId") DO NOTHING;
  END IF;
END
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'Events'
      AND column_name = 'location'
  ) THEN
    INSERT INTO "Addresses" (
      "id",
      "entityType",
      "entityId",
      "address",
      "latitude",
      "longitude",
      "metadata",
      "createdAt",
      "updatedAt"
    )
    SELECT
      uuidv7(),
      'event',
      "id",
      "location"->>'address',
      COALESCE(
        NULLIF("location"->>'latitude', '')::DOUBLE PRECISION,
        NULLIF("location"->'coordinates'->>'latitude', '')::DOUBLE PRECISION
      ),
      COALESCE(
        NULLIF("location"->>'longitude', '')::DOUBLE PRECISION,
        NULLIF("location"->'coordinates'->>'longitude', '')::DOUBLE PRECISION
      ),
      CASE
        WHEN jsonb_typeof("location") = 'object'
          THEN "location" - 'address' - 'latitude' - 'longitude' - 'coordinates'
        ELSE '{}'::JSONB
      END,
      "createdAt",
      "updatedAt"
    FROM "Events"
    ON CONFLICT ("entityType", "entityId") DO NOTHING;
  END IF;
END
$$;

DROP INDEX IF EXISTS "events_location_gix";
DROP INDEX IF EXISTS "users_address_gix";

ALTER TABLE IF EXISTS "Events" DROP COLUMN IF EXISTS "location";
ALTER TABLE IF EXISTS "Users" DROP COLUMN IF EXISTS "address";
