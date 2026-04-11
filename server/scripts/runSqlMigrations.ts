import fs from 'fs/promises';
import path from 'path';
import dotenv from 'dotenv';

import { disconnect, getDBConnection } from '../src/connections/db';
import type { Sequelize, Transaction } from 'sequelize';

export interface MigrationContext {
  sequelize: Sequelize;
  transaction: Transaction;
}

dotenv.config();

function parseMigrationFolderName(argv: string[]) {
  const folderArg = argv.find((arg) => arg.startsWith('--folder='));
  if (folderArg) {
    return folderArg.slice('--folder='.length);
  }

  const positional = argv.find((arg) => !arg.startsWith('--'));
  if (positional) {
    return positional;
  }

  throw new Error(
    'Migration folder name is required. Use --folder=<name> or pass it as the first positional argument.',
  );
}

async function findMigrationFolder(rootDirectory: string, folderName: string) {
  const queue = [rootDirectory];
  const matches: string[] = [];

  while (queue.length > 0) {
    const currentDirectory = queue.shift();
    if (!currentDirectory) {
      continue;
    }

    const entries = await fs.readdir(currentDirectory, { withFileTypes: true });

    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const absolutePath = path.join(currentDirectory, entry.name);
      if (entry.name === folderName) {
        matches.push(absolutePath);
      }
      queue.push(absolutePath);
    }
  }

  if (matches.length === 0) {
    throw new Error(`Migration folder "${folderName}" not found under ${rootDirectory}.`);
  }

  if (matches.length > 1) {
    throw new Error(`Migration folder name "${folderName}" is ambiguous. Matches: ${matches.join(', ')}`);
  }

  return matches[0];
}

async function getSortedMigrationFiles(directory: string) {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && /\.(sql|ts|js)$/.test(entry.name))
    .map((entry) => entry.name)
    .sort((a, b) => a.localeCompare(b));
}

async function main() {
  const folderName = parseMigrationFolderName(process.argv.slice(2));
  const migrationsRoot = path.resolve(__dirname, '../src/database');
  const migrationDirectory = await findMigrationFolder(migrationsRoot, folderName);
  const migrationFiles = await getSortedMigrationFiles(migrationDirectory);

  if (migrationFiles.length === 0) {
    throw new Error(`No .sql migration files found in ${migrationDirectory}.`);
  }

  const sequelize = getDBConnection()!;
  await sequelize.authenticate();

  try {
    await sequelize.transaction(async (transaction) => {
      for (const fileName of migrationFiles) {
        const filePath = path.join(migrationDirectory, fileName);
        console.log(`Running migration ${folderName}/${fileName}`);
        if (fileName.endsWith('.sql')) {
          const sql = await fs.readFile(filePath, 'utf8');
          await sequelize.query(sql, { transaction });
        } else {
          const mod = await import(filePath);
          await mod.default({ sequelize, transaction });
        }
      }
    });
  } finally {
    await disconnect();
  }
}

main()
  .then(() => {
    console.log('SQL migrations completed.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('SQL migrations failed:', error);
    disconnect().finally(() => process.exit(1));
  });
