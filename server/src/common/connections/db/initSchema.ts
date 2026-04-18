import fs from 'fs/promises';
import path from 'path';
import type { Sequelize } from 'sequelize';
import { syncRegisteredModels } from './syncModels';

function getBootstrapDirectory() {
  return path.resolve(__dirname, '../../../migrations/bootstrap');
}

async function readBootstrapSqlFiles() {
  const directory = getBootstrapDirectory();
  const entries = await fs.readdir(directory, { withFileTypes: true });
  const sqlFiles = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith('.sql'))
    .map((entry) => entry.name)
    .sort((a, b) => a.localeCompare(b));

  return Promise.all(
    sqlFiles.map(async (fileName) => ({
      fileName,
      sql: await fs.readFile(path.join(directory, fileName), 'utf8'),
    })),
  );
}

export async function ensureDatabaseSchema(sequelize: Sequelize) {
  const bootstrapFiles = await readBootstrapSqlFiles();

  for (const file of bootstrapFiles) {
    await sequelize.query(file.sql);
  }
  await syncRegisteredModels();
}
