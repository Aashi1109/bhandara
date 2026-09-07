-- Public / private events. 'restricted' exists in the enum for parity with the
-- other visibility columns but has no behaviour wired up in the API yet.
--
-- Named enum_Events_visibility to match what Sequelize's DataTypes.ENUM
-- generates for Event.visibility — syncRegisteredModels may have created the
-- type already, and ALTER TABLE has to reference the same one.
--
-- Defaulting to 'public' keeps every existing event discoverable exactly as before.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'enum_Events_visibility'
    ) THEN
        CREATE TYPE "enum_Events_visibility" AS ENUM ('public', 'private', 'restricted');
    END IF;
END $$;

ALTER TABLE "Events"
ADD COLUMN IF NOT EXISTS "visibility" "enum_Events_visibility" NOT NULL DEFAULT 'public';

CREATE INDEX IF NOT EXISTS "events_visibility_idx" ON "Events"("visibility");
