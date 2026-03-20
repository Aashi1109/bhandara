import type {
  IBaseThread,
  IEntitySaveSummary,
  IEvent,
  IMessage,
  IPaginationParams,
  ISavedEntity,
  ISavedEntityListItem,
  PaginatedResult,
} from '@/definitions/types';
import { BadRequestError, NotFoundError } from '@/exceptions';
import EventService from '@/features/events/service';
import MessageService from '@/features/messages/service';
import ThreadService from '@/features/threads/service';
import { findAllWithPagination } from '@/utils/dbUtils';

import {
  SUPPORTED_SAVED_ENTITY_TYPES,
  type SupportedSavedEntityType,
} from './constants';
import { SavedEntity } from './model';

type SavedEntityRecord = ISavedEntity & {
  deletedAt?: Date | null;
};

type SavedEntityPayload = IEvent | IBaseThread | IMessage | null;

class SavedEntityService {
  private readonly eventService: EventService;
  private readonly threadService: ThreadService;
  private readonly messageService: MessageService;

  constructor() {
    this.eventService = new EventService();
    this.threadService = new ThreadService();
    this.messageService = new MessageService();
  }

  isSupportedEntityType(
    entityType: string,
  ): entityType is SupportedSavedEntityType {
    return SUPPORTED_SAVED_ENTITY_TYPES.includes(
      entityType as SupportedSavedEntityType,
    );
  }

  private async findEntity(
    entityType: SupportedSavedEntityType,
    entityId: string,
  ): Promise<SavedEntityPayload> {
    switch (entityType) {
      case 'event':
        return this.eventService.getEventPreview(entityId);
      case 'thread':
        return this.threadService.getById(entityId);
      case 'message':
        return this.messageService.getById(entityId);
      default:
        return null;
    }
  }

  private async assertEntityExists(
    entityType: SupportedSavedEntityType,
    entityId: string,
  ) {
    const entity = await this.findEntity(entityType, entityId);
    if (!entity) {
      throw new NotFoundError('Entity not found');
    }
    return entity;
  }

  private async getSaveCount(
    entityType: SupportedSavedEntityType,
    entityId: string,
  ) {
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
    await this.assertEntityExists(entityType, entityId);

    const [savedEntity, saveCount] = await Promise.all([
      SavedEntity.findOne({
        where: { userId, entityType, entityId },
        raw: true,
      }) as Promise<SavedEntityRecord | null>,
      this.getSaveCount(entityType, entityId),
    ]);

    return this.toSaveSummary(
      entityType,
      entityId,
      !!savedEntity,
      saveCount,
      savedEntity?.updatedAt ?? null,
    );
  }

  async saveEntity(
    userId: string,
    entityType: SupportedSavedEntityType,
    entityId: string,
  ): Promise<IEntitySaveSummary> {
    await this.assertEntityExists(entityType, entityId);

    const existing = await SavedEntity.findOne({
      where: { userId, entityType, entityId },
      paranoid: false,
    });

    if (!existing) {
      await SavedEntity.create({
        userId,
        entityType,
        entityId,
      } as Partial<ISavedEntity>);
    } else if (existing.deletedAt) {
      await existing.restore();
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
    filters: { entityType?: SupportedSavedEntityType },
    pagination: Partial<IPaginationParams> = {},
  ): Promise<PaginatedResult<ISavedEntityListItem>> {
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

    const items = await Promise.all(
      data.items.map(async (item) => ({
        ...(item as unknown as ISavedEntity),
        entity: await this.findEntity(
          item.entityType as SupportedSavedEntityType,
          item.entityId,
        ),
      })),
    );

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
