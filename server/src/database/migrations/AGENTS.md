# Migrations Guide

## How the runner works

Migrations are plain SQL or JS/TS files inside numbered folders. The runner (`scripts/runSqlMigrations.ts`) executes them with:

```sh
pnpm migrate --folder=<folder_name>
```

- Folders are numbered for ordering clarity (`000_init`, `010_...`, `080_...`)
- Files inside a folder run in **lexical order** (`01_*.sql`, `02_*.sql`, ...)
- All files in a folder run inside a **single transaction** — if any file fails, the entire folder rolls back
- SQL files are executed directly; JS/TS files are dynamically imported and called with a `MigrationContext`

---

## Folder naming

```sh
<number>_<short_description>/
```

- Use 3-digit increments of 10 (`010`, `020`, `080`) to leave room for future insertions
- Use snake_case for the description
- Examples: `080_user_settings`, `090_add_event_tags`

---

## File naming inside a folder

```sh
01_<what_it_does>.sql
02_<what_it_does>.sql
03_<what_it_does>.ts   ← for complex programmatic migrations
```

- Start at `01_`, increment by 1
- Keep names descriptive: `01_create_table.sql`, `02_backfill.sql`, `03_drop_old_columns.sql`
- Typical order: create → backfill → cleanup

---

## SQL migration files

Plain SQL. No `BEGIN`/`COMMIT` — the runner owns the transaction.

```sql
-- 01_create_user_settings.sql

CREATE TABLE IF NOT EXISTS "UserSettings" (
  "id"            UUID        PRIMARY KEY DEFAULT uuidv7(),
  "userId"        UUID        NOT NULL UNIQUE REFERENCES "Users"("id") ON DELETE CASCADE,
  "notifications" JSONB       NOT NULL DEFAULT '{"events":true,"chat":true}'::JSONB,
  "createdAt"     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS "user_settings_userId_idx" ON "UserSettings"("userId");
```

**Rules:**

- Always use `CREATE TABLE IF NOT EXISTS` and `CREATE INDEX IF NOT EXISTS`
- Always use `ADD COLUMN IF NOT EXISTS` for ALTER TABLE
- Use `uuidv7()` for UUID primary keys (available via bootstrap extension)
- Use `TIMESTAMPTZ` for all timestamps
- Table names use `"PascalCase"` with double quotes (Sequelize convention)
- Column names use `"camelCase"` with double quotes

---

## TS/JS migration files

Use when the migration requires programmatic logic (data transformation, conditional logic, calling services).

The file must **default export** an async function that receives `MigrationContext`. The runner calls it and manages the transaction — do not commit or rollback inside the file.

```typescript
// 03_complex_backfill.ts
import type { MigrationContext } from '../../../scripts/runSqlMigrations';

export default async function ({ sequelize, transaction }: MigrationContext): Promise<void> {
  const [users] = await sequelize.query(
    `SELECT id, meta FROM "Users" WHERE meta->>'legacyField' IS NOT NULL`,
    { transaction },
  );

  for (const user of users as any[]) {
    await sequelize.query(
      `UPDATE "OtherTable" SET "value" = :value WHERE "userId" = :userId`,
      {
        replacements: { value: user.meta.legacyField, userId: user.id },
        transaction,
      },
    );
  }
}
```

**Rules:**

- Always pass `{ transaction }` to every query
- Never call `transaction.commit()` or `transaction.rollback()` — the runner does this
- Never import Sequelize models directly (they bootstrap the DB connection on import) — use raw `sequelize.query()` instead
- Keep the function focused; split into multiple files if logic is complex

---

## Backfill pattern

When moving data from one column/table to another, always use two files:

```sh
01_create_new_table.sql   ← schema change
02_backfill.sql           ← migrate existing data
```

Backfill SQL should always use `ON CONFLICT ... DO NOTHING` to be idempotent:

```sql
INSERT INTO "NewTable" ("id", "userId", "value")
SELECT uuidv7(), "id", meta->>'oldField'
FROM "Users"
ON CONFLICT ("userId") DO NOTHING;
```

---

## Adding a new migration — checklist

1. Pick the next folder number (look at existing folders, add 10)
2. Create `server/src/database/migrations/<number>_<description>/`
3. Create `01_create_*.sql` for schema changes
4. Create `02_backfill.sql` if existing data needs migrating
5. Create `03_*.ts` only if programmatic logic is needed
6. Run with `pnpm migrate --folder=<folder_name>`
7. If migration touches a model, update the corresponding Sequelize model file in `src/features/`

---

## Common mistakes to avoid

- **Do not** put `BEGIN`/`COMMIT` in SQL files — the runner wraps the whole folder in one transaction
- **Do not** use `KEYS` pattern in cache invalidation — use `SCAN` (already handled in `RedisCache.invalidateCache`)
- **Do not** hardcode UUIDs — use `uuidv7()`
- **Do not** drop columns in the same migration that creates the replacement — use separate migrations with a deprecation window
- **Do not** import Sequelize models in TS migration files — use raw queries via the `sequelize` from context
