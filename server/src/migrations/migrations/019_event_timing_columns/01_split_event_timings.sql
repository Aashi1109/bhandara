ALTER TABLE "Events"
  ADD COLUMN IF NOT EXISTS "startTime" TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS "endTime" TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS "isDraft" BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS "cancelledAt" TIMESTAMPTZ;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'Events'
      AND column_name = 'timings'
  ) THEN
    UPDATE "Events"
    SET
      "startTime" = COALESCE("startTime", CAST("timings"->>'start' AS TIMESTAMPTZ)),
      "endTime" = COALESCE("endTime", CAST("timings"->>'end' AS TIMESTAMPTZ))
    WHERE "timings" IS NOT NULL
      AND ("startTime" IS NULL OR "endTime" IS NULL);
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
      AND column_name = 'status'
  ) THEN
    UPDATE "Events"
    SET
      "isDraft" = COALESCE("isDraft", false) OR "status" = 'draft',
      "cancelledAt" = CASE
        WHEN "status" = 'cancelled' THEN COALESCE("cancelledAt", "updatedAt", NOW())
        ELSE "cancelledAt"
      END;
  END IF;
END
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM "Events"
    WHERE "startTime" IS NULL OR "endTime" IS NULL
  ) THEN
    RAISE EXCEPTION 'Cannot finalize event timing migration while startTime or endTime is NULL';
  END IF;
END
$$;

ALTER TABLE "Events"
  ALTER COLUMN "startTime" SET NOT NULL,
  ALTER COLUMN "endTime" SET NOT NULL;

CREATE INDEX IF NOT EXISTS "events_startTime_idx" ON "Events"("startTime");
CREATE INDEX IF NOT EXISTS "events_endTime_idx" ON "Events"("endTime");
CREATE INDEX IF NOT EXISTS "events_isDraft_idx" ON "Events"("isDraft");
CREATE INDEX IF NOT EXISTS "events_cancelledAt_idx" ON "Events"("cancelledAt");
CREATE INDEX IF NOT EXISTS "events_active_startTime_idx" ON "Events"("startTime")
  WHERE "cancelledAt" IS NULL AND "isDraft" = FALSE;
CREATE INDEX IF NOT EXISTS "events_active_endTime_idx" ON "Events"("endTime")
  WHERE "cancelledAt" IS NULL AND "isDraft" = FALSE;

ALTER TABLE "Events" DROP COLUMN IF EXISTS "status";
ALTER TABLE "Events" DROP COLUMN IF EXISTS "timings";

DROP TYPE IF EXISTS "EventStatus";
