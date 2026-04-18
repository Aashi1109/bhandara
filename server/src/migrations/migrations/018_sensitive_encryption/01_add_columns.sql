ALTER TABLE "Users"
  ADD COLUMN IF NOT EXISTS "__sid" TEXT,
  ADD COLUMN IF NOT EXISTS "emailLookupHash" TEXT;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Users_email_key'
  ) THEN
    ALTER TABLE "Users" DROP CONSTRAINT "Users_email_key";
  END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS "users_emailLookupHash_key"
  ON "Users" ("emailLookupHash")
  WHERE "emailLookupHash" IS NOT NULL;
