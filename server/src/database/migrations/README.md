# SQL Migrations

Migration folders are ordered with numeric prefixes so execution order is visible
from the filesystem.

Within each folder, SQL files should stay in lexical order:

- `01_*.sql`
- `02_*.sql`

Use `pnpm migrate --folder=<folder_name>` to run a specific migration folder.
