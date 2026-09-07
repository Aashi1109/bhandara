-- Add media variant columns for dynamic loading support.
-- thumbnails: square-cropped URLs at sm/md/xl for list/grid/strip views
-- variants:   aspect-maintained URLs at sm/md/xl for full-display (images only)
-- streamUrl:  HLS adaptive stream URL (videos only)

ALTER TABLE "Media"
  ADD COLUMN IF NOT EXISTS "thumbnails" JSONB,
  ADD COLUMN IF NOT EXISTS "variants"   JSONB,
  ADD COLUMN IF NOT EXISTS "streamUrl"  TEXT;
