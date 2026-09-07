import type { Sequelize } from 'sequelize';
import { syncRegisteredModels } from './syncModels';

export async function ensureDatabaseSchema(sequelize: Sequelize) {
  void sequelize;
  await syncRegisteredModels();
}
