Legacy/manual SQL reference files.

These files are not part of normal server startup anymore.

Runtime bootstrap now uses:
- `server/src/database/bootstrap/*.sql`
- centralized Sequelize model sync

Keep these files only for inspection or one-off manual database work.
