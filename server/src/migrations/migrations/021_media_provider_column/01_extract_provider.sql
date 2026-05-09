-- Move provider out of the storage JSONB into a dedicated column.

-- Create the enum type if it doesn't already exist (idempotent).
DO $$ BEGIN
  CREATE TYPE "enum_Media_provider" AS ENUM ('local', 's3', 'gcs', 'cloudinary', 'supabase');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "Media"
  ADD COLUMN IF NOT EXISTS "provider" "enum_Media_provider"
    NOT NULL DEFAULT 'supabase';

-- Backfill from existing storage JSONB.
UPDATE "Media"
SET "provider" = (storage->>'provider')::"enum_Media_provider"
WHERE storage->>'provider' IS NOT NULL;

-- Remove the now-redundant key from the JSONB column.
UPDATE "Media"
SET storage = storage - 'provider';
