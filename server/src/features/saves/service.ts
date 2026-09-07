import type {
  IBaseUser,
  IBaseThread,
  IEntitySaveSummary,
  IEvent,
  IMessage,
  IPaginationParams,
  ISavedEntity,
  ISavedEntityListItem,
  PaginatedResult,
} from '@/common/definitions/types';
import { BadRequestError, NotFoundError } from '@/common/exceptions';
import EventService from '@/features/events/service';
import MessageService from '@/features/messages/service';
import ThreadService from '@/features/threads/service';
import UserService from '@/features/users/service';
import { getSafeUser } from '@/features/users/helpers';
import { decodePaginationCursor, encodePaginationCursor, findAllWithPagination } from '@/common/utils/dbUtils';

import { SUPPORTED_SAVED_ENTITY_TYPES, type SupportedSavedEntityType } from './constants';
import { SavedEntity } from './model';

type SavedEntityRecord = ISavedEntity;

type SavedEntityPayload = IEvent | IBaseThread | IMessage | IBaseUser | null;

class SavedEntityService {
  private readonly eventService: EventService;
  private readonly threadService: ThreadService;
  private readonly messageService: MessageService;
  private readonly userService: UserService;

  constructor() {
    this.eventService = new EventService();
    this.threadService = new ThreadService();
    this.messageService = new MessageService();
    this.userService = new UserService();
  }

  isSupportedEntityType(entityType: string): entityType is SupportedSavedEntityType {
    return SUPPORTED_SAVED_ENTITY_TYPES.includes(entityType as SupportedSavedEntityType);
  }

  private async findEntity(
    entityType: SupportedSavedEntityType,
    entityId: string,
    viewerId?: string,
  ): Promise<SavedEntityPayload> {
    switch (entityType) {
      case 'event':
        return this.eventService.getEventPreview(entityId, viewerId);
      case 'thread':
        return this.threadService.getById(entityId);
      case 'message':
        return this.messageService.getById(entityId);
      case 'user':
        return this.userService.getById(entityId).then((user) => {
          if (!user) {
            return null;
          }
          const safe = getSafeUser(user);
          return {
            id: safe.id,
            name: safe.name,
            avatarUrl: safe.media?.publicUrl ?? safe.media?.url ?? safe.profilePic ?? null,
          } as unknown as IBaseUser;
        });
      default:
        return null;
    }
  }

  private getSearchText(item: ISavedEntityListItem, entityType: SupportedSavedEntityType): string {
    const entity = item.entity as unknown as Record<string, unknown> | null;
    if (!entity) {
      return '';
    }

    switch (entityType) {
      case 'event': {
        const location =
          entity.location && typeof entity.location === 'object' ? (entity.location as Record<string, unknown>) : null;
        return [entity.name, entity.description, location?.address]
          .filter((value): value is string => typeof value === 'string')
          .join(' ');
      }
      case 'thread':
        return [entity.title, entity.type].filter((value): value is string => typeof value === 'string').join(' ');
      case 'message': {
        const content =
          entity.content && typeof entity.content === 'object' ? (entity.content as Record<string, unknown>) : null;
        const user = entity.user && typeof entity.user === 'object' ? (entity.user as Record<string, unknown>) : null;
        return [content?.text, user?.name].filter((value): value is string => typeof value === 'string').join(' ');
      }
      case 'user':
        return [entity.name, entity.username, entity.bio]
          .filter((value): value is string => typeof value === 'string')
          .join(' ');
      default:
        return '';
    }
  }

  private async hydrateSavedItems(items: SavedEntityRecord[], viewerId?: string): Promise<ISavedEntityListItem[]> {
    if (!items.length) return [];

    const byType: Partial<Record<SupportedSavedEntityType, string[]>> = {};
    items.forEach((item) => {
      const type = item.entityType as SupportedSavedEntityType;
      if (!byType[type]) byType[type] = [];
      byType[type]!.push(item.entityId);
    });

    const entityMap: Record<string, SavedEntityPayload> = {};

    await Promise.all(
      (Object.entries(byType) as [SupportedSavedEntityType, string[]][]).map(async ([type, ids]) => {
        switch (type) {
          case 'event': {
            await Promise.all(
              ids.map(async (id) => {
                entityMap[id] = await this.eventService.getEventPreview(id, viewerId);
              }),
            );
            break;
          }
          case 'thread': {
            const { items: threads } = await this.threadService.getAll({ id: ids }, { limit: ids.length });
            (threads as IBaseThread[]).forEach((t) => {
              entityMap[t.id] = t;
            });
            break;
          }
          case 'message': {
            const msgs = await this.messageService.getByIds(ids);
            msgs.forEach((m) => {
              entityMap[m.id] = m;
            });
            break;
          }
          case 'user': {
            const usersMap = await this.userService.getUserProfiles(
              ids,
              (u) =>
                ({
                  id: u.id,
                  name: u.name,
                  avatarUrl: (u.media as any)?.publicUrl ?? (u.media as any)?.url ?? (u as any).profilePic ?? null,
                }) as unknown as IBaseUser,
            );
            Object.assign(entityMap, usersMap);
            break;
          }
        }
      }),
    );

    return items.map((item) => ({
      ...(item as ISavedEntity),
      entity: entityMap[item.entityId] ?? null,
    }));
  }

  private async listSavedEntitiesByQuery(
    userId: string,
    filters: {
      entityType?: SupportedSavedEntityType;
      query: string;
    },
    pagination: Partial<IPaginationParams> = {},
  ): Promise<PaginatedResult<ISavedEntityListItem>> {
    const { limit = 10, next = null, sortBy = 'updatedAt', sortOrder = 'desc' } = pagination;
    const where: Record<string, unknown> = { userId };
    if (filters.entityType) {
      where.entityType = filters.entityType;
    }

    const rows = (await SavedEntity.findAll({
      where,
      raw: true,
      limit: 200,
      order: [
        [sortBy, sortOrder.toUpperCase()],
        ['id', sortOrder.toUpperCase()],
      ],
    })) as SavedEntityRecord[];

    const hydrated = await this.hydrateSavedItems(rows, userId);
    const normalizedQuery = filters.query.trim().toLowerCase();
    const matched = hydrated.filter((item) => {
      if (!item.entity) {
        return false;
      }
      const searchText = this.getSearchText(item, item.entityType as SupportedSavedEntityType).toLowerCase();
      return searchText.includes(normalizedQuery);
    });

    const cursor = decodePaginationCursor(next);
    const afterCursor = !cursor
      ? matched
      : matched.filter((item) => {
          const rawSortValue = item[sortBy as keyof ISavedEntityListItem];
          if (!(rawSortValue instanceof Date) && typeof rawSortValue !== 'string') {
            return true;
          }
          const itemSortValue = rawSortValue instanceof Date ? rawSortValue : new Date(rawSortValue);
          const cursorDate = new Date(cursor.sortValue);
          return sortOrder === 'asc' ? itemSortValue > cursorDate : itemSortValue < cursorDate;
        });

    const pagedWindow = afterCursor.slice(0, limit + 1);
    const hasNext = pagedWindow.length > limit;
    const items = pagedWindow.slice(0, limit);
    const nextSortValue =
      hasNext && items.length ? (items[items.length - 1][sortBy as keyof ISavedEntityListItem] as Date | string) : null;

    return {
      items,
      pagination: {
        limit,
        total: matched.length,
        hasNext,
        next: nextSortValue ? encodePaginationCursor(nextSortValue) : null,
        sortBy,
        sortOrder,
      },
    };
  }

  private async assertEntityExists(entityType: SupportedSavedEntityType, entityId: string, viewerId?: string) {
    const entity = await this.findEntity(entityType, entityId, viewerId);
    if (!entity) {
      throw new NotFoundError('Entity not found');
    }
    return entity;
  }

  private async getSaveCount(entityType: SupportedSavedEntityType, entityId: string) {
    return SavedEntity.count({
      where: { entityType, entityId },
    });
  }

  private toSaveSummary(
    entityType: SupportedSavedEntityType,
    entityId: string,
    saved: boolean,
    saveCount: number,
    savedAt: Date | string | null,
  ): IEntitySaveSummary {
    return {
      entityType,
      entityId,
      saved,
      saveCount,
      savedAt,
    };
  }

  async getSaveState(
    userId: string,
    entityType: SupportedSavedEntityType,
    entityId: string,
  ): Promise<IEntitySaveSummary> {
    await this.assertEntityExists(entityType, entityId, userId);

    const [savedEntity, saveCount] = await Promise.all([
      SavedEntity.findOne({
        where: { userId, entityType, entityId },
        raw: true,
      }) as Promise<SavedEntityRecord | null>,
      this.getSaveCount(entityType, entityId),
    ]);

    return this.toSaveSummary(entityType, entityId, !!savedEntity, saveCount, savedEntity?.updatedAt ?? null);
  }

  async saveEntity(
    userId: string,
    entityType: SupportedSavedEntityType,
    entityId: string,
  ): Promise<IEntitySaveSummary> {
    if (entityType === 'user' && entityId === userId) {
      throw new BadRequestError('You cannot save your own profile');
    }

    await this.assertEntityExists(entityType, entityId, userId);

    const existing = await SavedEntity.findOne({
      where: { userId, entityType, entityId },
    });

    if (!existing) {
      await SavedEntity.create({
        userId,
        entityType,
        entityId,
      } as any);
    } else {
      existing.updatedAt = new Date();
      await existing.save();
    }

    return this.getSaveState(userId, entityType, entityId);
  }

  async unsaveEntity(
    userId: string,
    entityType: SupportedSavedEntityType,
    entityId: string,
  ): Promise<IEntitySaveSummary> {
    // Deliberately not viewer-scoped: un-saving must keep working even if the
    // entity has since gone private on the user.
    await this.assertEntityExists(entityType, entityId);

    const existing = await SavedEntity.findOne({
      where: { userId, entityType, entityId },
    });

    if (existing) {
      await existing.destroy();
    }

    const saveCount = await this.getSaveCount(entityType, entityId);
    return this.toSaveSummary(entityType, entityId, false, saveCount, null);
  }

  async listSavedEntities(
    userId: string,
    filters: { entityType?: SupportedSavedEntityType; query?: string },
    pagination: Partial<IPaginationParams> = {},
  ): Promise<PaginatedResult<ISavedEntityListItem>> {
    if (filters.query?.trim()) {
      return this.listSavedEntitiesByQuery(
        userId,
        {
          entityType: filters.entityType,
          query: filters.query,
        },
        pagination,
      );
    }

    const where: Record<string, unknown> = { userId };
    if (filters.entityType) {
      where.entityType = filters.entityType;
    }

    const data = await findAllWithPagination(
      SavedEntity,
      { where },
      {
        ...pagination,
        sortBy: 'updatedAt',
        sortOrder: pagination.sortOrder ?? 'desc',
      },
    );

    const items = await this.hydrateSavedItems(data.items as SavedEntityRecord[], userId);

    return {
      items,
      pagination: data.pagination,
    };
  }

  validateEntityType(entityType: string): SupportedSavedEntityType {
    if (!this.isSupportedEntityType(entityType)) {
      throw new BadRequestError('Unsupported entity type');
    }

    return entityType;
  }
}

export default SavedEntityService;
