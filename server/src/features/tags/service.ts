import { IEvent, IPaginationParams, ITag } from "@/definitions/types";
import { findAllWithPagination } from "@/utils/dbUtils";
import { validateTagCreate, validateTagUpdate } from "./validation";
import { Tag } from "./model";
import { Event } from "../events/model";
import {
  getTagCache,
  setTagCache,
  deleteTagCache,
  getEventTagsCache,
  setEventTagsCache,
  deleteEventTagsCache,
  getSubTagsCache,
  setSubTagsCache,
  deleteSubTagsCache,
} from "./helpers";
import { NotFoundError } from "@/exceptions";

class TagService {
  private readonly getCache = getTagCache;
  private readonly setCache = setTagCache;
  private readonly deleteCache = deleteTagCache;

  constructor() {}

  async getById(id: string): Promise<ITag | null> {
    const cached = await this.getCache(id);
    if (cached) return cached;
    const res = await Tag.findByPk(id, { raw: true });
    if (res) await this.setCache(id, res);
    return res;
  }

  async getAll(
    where: Record<string, any> = {},
    pagination?: Partial<IPaginationParams>,
    select?: string
  ) {
    return findAllWithPagination(Tag, { where }, pagination, select);
  }

  async _getByIdNoCache(id: string): Promise<ITag | null> {
    const res = await Tag.findByPk(id, { raw: true });
    return res;
  }

  async getRootTags() {
    const [results] = await Tag.sequelize!.query(
      `SELECT t.*, COUNT(c.id) > 0 AS "hasChildren" FROM "Tags" t
       LEFT JOIN "Tags" c ON c."parentId" = t."id" AND c."deletedAt" IS NULL
       WHERE t."deletedAt" IS NULL AND t."parentId" IS NULL
       GROUP BY t."id";`
    );
    return results as ITag[];
  }

  async getAllEventTags(event?: IEvent) {
    const cacheKey = event?.id as string;
    if (cacheKey) {
      const cached = await getEventTagsCache(cacheKey);
      if (cached) return cached;
    }
    const tagIds = event?.tags || [];

    if (!tagIds.length) return [];

    const data = await findAllWithPagination(
      Tag,
      { where: { id: tagIds } },
      { limit: tagIds.length }
    );

    const items = data.items;
    if (cacheKey && items) {
      await setEventTagsCache(cacheKey, items);
    }
    return items;
  }

  async create<U extends Partial<Omit<ITag, "id" | "updatedAt">>>(data: U) {
    const res = await validateTagCreate(data, async (validatedData: U) => {
      const row = await Tag.create(validatedData as Partial<ITag>);
      return row.toJSON() as ITag;
    });
    const created = res as ITag;
    if (created) {
      await this.setCache(created.id, created);
    }
    return res;
  }

  async update<U extends Partial<ITag>>(id: string, data: U): Promise<ITag> {
    const res = await validateTagUpdate(data, async (validatedData: U) => {
      const row = await Tag.findByPk(id);
      if (!row) throw new Error("Tag not found");
      await row.update(validatedData as Partial<ITag>);
      return row.toJSON() as ITag;
    });
    await this.deleteCache(id);
    return res as ITag;
  }

  async delete(id: string): Promise<ITag | null> {
    const row = await Tag.findByPk(id);
    if (!row) return null;
    await row.destroy();
    await this.deleteCache(id);
    return row.toJSON() as ITag;
  }

  async dissociateTag(eventId: string, tagId: string) {
    const event = await Event.findByPk(eventId);
    if (!event) throw new NotFoundError("Event not found");
    const tags = new Set((event.tags || []) as string[]);

    if (!tags.has(tagId)) throw new NotFoundError("Tag not found");
    tags.delete(tagId);

    await event.update({ tags: Array.from(tags) });
    await deleteEventTagsCache(eventId);
    return true;
  }

  async getSubTags(tagId: string, limit?: number) {
    const cached = await getSubTagsCache(tagId);
    if (cached) return cached;
    const res = await findAllWithPagination(
      Tag,
      { where: { parentId: tagId } },
      limit ? { limit } : {}
    );
    if (res.items) await setSubTagsCache(tagId, res.items as ITag[]);
    return res;
  }
}

export default TagService;
