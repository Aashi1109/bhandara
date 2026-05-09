import type { IReaction, IPaginationParams } from '@/common/definitions/types';
import { findAllWithPagination } from '@/common/utils/dbUtils';
import { Reaction } from './model';
import { validateReactionCreate, validateReactionUpdate } from './validation';

import UserService, { toUserMini } from '@/features/users/service';
import { isEmpty } from '@/common/utils';
import { NotFoundError } from '@/common/exceptions';
import logger from '@/common/logger';
import EntityStatsService from '@/features/stats/service';
import { EAllowedReactionTables } from './constants';

class ReactionService {
  private readonly userService: UserService;
  private readonly entityStatsService: EntityStatsService;

  constructor() {
    this.userService = new UserService();
    this.entityStatsService = new EntityStatsService();
  }

  private async updateReactionCounter(contentId: string, by: number) {
    const [contentPath, entityId] = contentId.split('/');
    if (!entityId) return;

    if (contentPath === EAllowedReactionTables.Event) {
      await this.entityStatsService.incrementEventStat(entityId, 'reactionCount', by);
      return;
    }

    if (contentPath === EAllowedReactionTables.Thread) {
      await this.entityStatsService.incrementThreadStat(entityId, 'reactionCount', by);
      return;
    }

    if (contentPath === EAllowedReactionTables.Message) {
      await this.entityStatsService.incrementMessageStat(entityId, 'reactionCount', by);
    }
  }

  async getById(id: string): Promise<IReaction | null> {
    const res = await Reaction.findByPk(id, { raw: true });
    return res as IReaction | null;
  }

  async getAll(where: Record<string, any> = {}, pagination?: Partial<IPaginationParams>, select?: string) {
    return findAllWithPagination(Reaction, { where }, pagination, select);
  }

  async create<U extends Partial<Omit<IReaction, 'id' | 'updatedAt'>>>(data: U) {
    const res = await validateReactionCreate(data, async (validData) => {
      const row = await Reaction.create(validData as any);
      return row.toJSON() as IReaction;
    });
    if (res?.contentId) {
      await this.updateReactionCounter(res.contentId, 1);
    }
    return res as IReaction;
  }

  async update<U extends Partial<IReaction>>(id: string, data: U): Promise<IReaction> {
    const res = await validateReactionUpdate(data, async (validData) => {
      const row = await Reaction.findByPk(id);
      if (!row) throw new NotFoundError('Reaction not found');
      await row.update(validData as Partial<IReaction>);
      return row.toJSON() as IReaction;
    });
    return res as IReaction;
  }

  async delete(id: string, skipGet = false): Promise<IReaction | number | null> {
    if (skipGet) {
      return Reaction.destroy({ where: { id } });
    }
    const row = await Reaction.findByPk(id);
    if (!row) return null;
    await row.destroy();
    const deletedReaction = row.toJSON() as IReaction;
    await this.updateReactionCounter(deletedReaction.contentId, -1);
    return deletedReaction;
  }

  async getReactions(contentId: string, userId?: string) {
    const where: any = { contentId };
    if (userId) where.userId = userId;
    const data = await findAllWithPagination(
      Reaction,
      { where },
      {
        limit: 1000,
      },
    );
    let reactions = data.items || [];
    if (!isEmpty(reactions)) {
      reactions = await this.userService.getAndPopulateUserProfiles({
        data: reactions,
        searchKey: 'userId',
        populateKey: 'user',
        transformerFunction: toUserMini,
      });
    }
    return reactions;
  }

  async deleteByQuery(where: Partial<IReaction>) {
    const matchingRows = await Reaction.findAll({ where });
    const deletedRow = await Reaction.destroy({ where });
    await Promise.all(matchingRows.map((row) => this.updateReactionCounter((row.toJSON() as IReaction).contentId, -1)));
    logger.debug(`Deleted reaction rows: ${deletedRow}`);
    return matchingRows;
  }
}

export default ReactionService;
