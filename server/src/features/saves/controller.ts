import type { ICustomRequest, IRequestPagination } from '@/common/definitions/types';
import { BadRequestError } from '@/common/exceptions';
import type { Response } from 'express';

import SavedEntityService from './service';

const savedEntityService = new SavedEntityService();

const asString = (value: string | string[] | undefined) => (Array.isArray(value) ? value[0] : value);

const getEntityParams = (req: ICustomRequest) => {
  const entityType = asString(req.params.entityType);
  const entityId = asString(req.params.entityId);

  if (!entityType || !entityId) {
    throw new BadRequestError('Missing entity params');
  }

  return {
    entityType: savedEntityService.validateEntityType(entityType),
    entityId,
  };
};

export const getSavedEntityState = async (req: ICustomRequest, res: Response) => {
  const { entityType, entityId } = getEntityParams(req);
  const data = await savedEntityService.getSaveState(req.user.id, entityType, entityId);

  return res.status(200).json({ data });
};

export const saveEntity = async (req: ICustomRequest, res: Response) => {
  const { entityType, entityId } = getEntityParams(req);
  const data = await savedEntityService.saveEntity(req.user.id, entityType, entityId);

  return res.status(200).json({ data });
};

export const unsaveEntity = async (req: ICustomRequest, res: Response) => {
  const { entityType, entityId } = getEntityParams(req);
  const data = await savedEntityService.unsaveEntity(req.user.id, entityType, entityId);

  return res.status(200).json({ data });
};

export const listSavedEntities = async (req: ICustomRequest & IRequestPagination, res: Response) => {
  const entityTypeQuery = asString(req.query.entityType as string | undefined);
  const query = asString(req.query.query as string | undefined)?.trim();
  const entityType = entityTypeQuery ? savedEntityService.validateEntityType(entityTypeQuery) : undefined;

  const data = await savedEntityService.listSavedEntities(
    req.user.id,
    { entityType, query: query ? query : undefined },
    {
      ...req.pagination,
      sortBy: 'updatedAt',
      sortOrder: req.pagination?.sortOrder ?? 'desc',
    },
  );

  return res.status(200).json({ data });
};
