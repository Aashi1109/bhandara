import { IReaction, IPaginationParams } from "@/definitions/types";
import { findAllWithPagination } from "@/utils/dbUtils";
import { Reaction } from "./model";
import { validateReactionCreate, validateReactionUpdate } from "./validation";

import UserService from "@/features/users/service";
import { isEmpty } from "@/utils";
import logger from "@/logger";

class ReactionService {
  private readonly userService: UserService;

  constructor() {
    this.userService = new UserService();
  }

  async getById(id: string): Promise<IReaction | null> {
    const res = await Reaction.findByPk(id, { raw: true });
    return res as IReaction | null;
  }

  async getAll(
    where: Record<string, any> = {},
    pagination?: Partial<IPaginationParams>,
    select?: string
  ) {
    return findAllWithPagination(Reaction, where, pagination, select);
  }

  async create<U extends Partial<Omit<IReaction, "id" | "updatedAt">>>(
    data: U
  ) {
    const res = await validateReactionCreate(data, async (validData) => {
      const row = await Reaction.create(validData as Partial<IReaction>);
      return row.toJSON() as IReaction;
    });
    return res as IReaction;
  }

  async update<U extends Partial<IReaction>>(
    id: string,
    data: U
  ): Promise<IReaction> {
    const res = await validateReactionUpdate(data, async (validData) => {
      const row = await Reaction.findByPk(id);
      if (!row) throw new Error("Reaction not found");
      await row.update(validData as Partial<IReaction>);
      return row.toJSON() as IReaction;
    });
    return res as IReaction;
  }

  async delete(
    id: string,
    skipGet = false
  ): Promise<IReaction | number | null> {
    if (skipGet) {
      return Reaction.destroy({ where: { id } });
    }
    const row = await Reaction.findByPk(id);
    if (!row) return null;
    await row.destroy();
    return row.toJSON() as IReaction;
  }

  async getReactions(contentId: string, userId?: string) {
    const where: any = { contentId };
    if (userId) where.userId = userId;
    const data = await findAllWithPagination(Reaction, where, {
      limit: 1000,
    });
    let reactions = data.items || [];
    if (!isEmpty(reactions)) {
      reactions = await this.userService.getAndPopulateUserProfiles({
        data: reactions,
        searchKey: "userId",
        populateKey: "user",
      });
    }
    return reactions;
  }

  async deleteByQuery(where: Partial<IReaction>) {
    const matchingRows = await Reaction.findAll({ where });
    const deletedRow = await Reaction.destroy({ where });
    logger.debug(`Deleted reaction rows: ${deletedRow}`);
    return matchingRows;
  }
}

export default ReactionService;
