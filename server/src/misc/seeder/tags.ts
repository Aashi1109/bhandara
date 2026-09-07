import type { Sequelize, Transaction } from 'sequelize';
import { Tag } from '@/features/tags/model';
import { fallbackTagSeeds } from '../clusterSeedConfig';

export async function ensureTags(transaction: Transaction) {
  await Tag.bulkCreate(fallbackTagSeeds as any, {
    transaction,
    ignoreDuplicates: true,
  });

  return Tag.findAll({
    attributes: ['id'],
    raw: true,
    transaction,
  });
}

export async function ensureSeedTagIds(sequelize: Sequelize) {
  const transaction = await sequelize.transaction();

  try {
    const tags = await ensureTags(transaction);
    await transaction.commit();
    return tags.map((tag) => String(tag.id));
  } catch (error) {
    await transaction.rollback();
    throw error;
  }
}
