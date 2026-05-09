import { type ICustomRequest, type IRequestPagination } from '@/common/definitions/types';
import type { Response } from 'express';
import TagsService from './service';
import { pick } from '@/common/utils';

const tagsService = new TagsService();

export const getTags = async (req: ICustomRequest & IRequestPagination, res: Response) => {
  const { eventId, createdBy, rootOnly, parentId } = req.query;

  if (rootOnly === 'true') {
    const rootTags = await tagsService.getRootTags();
    return res.status(200).json({ data: rootTags });
  }

  const where: Record<string, string | null> = {};
  if (eventId) where.eventId = eventId as string;
  if (createdBy) where.createdBy = createdBy as string;
  if (parentId) where.parentId = parentId as string;
  else if (rootOnly === 'false' || !rootOnly) {
    // If not root only and no parentId, we still might want to filter?
    // But for now, let's just ensure parentId works.
  }

  const tags = await tagsService.getAll({ where }, req.pagination);
  return res.status(200).json({ data: tags });
};

export const createTag = async (req: ICustomRequest, res: Response) => {
  const createData = pick(req.body, ['name', 'value', 'description']);
  const tag = await tagsService.create(createData);
  return res.status(201).json({ data: tag });
};

export const getTagById = async (req: ICustomRequest, res: Response) => {
  const { tagId } = req.params;
  const tag = await tagsService.getById(tagId as string);

  return res.status(200).json({ data: tag });
};

export const updateTag = async (req: ICustomRequest, res: Response) => {
  const { tagId } = req.params;
  const updateData = pick(req.body, ['name', 'value', 'description']);
  const tag = await tagsService.update(tagId as string, updateData);

  return res.status(200).json({ data: tag });
};

export const deleteTag = async (req: ICustomRequest, res: Response) => {
  const { tagId } = req.params;
  const tag = await tagsService.delete(tagId as string);

  return res.status(200).json({ data: tag });
};

export const getSubTags = async (req: ICustomRequest, res: Response) => {
  const { tagId } = req.params;
  const subTags = await tagsService.getSubTags(tagId as string);

  return res.status(200).json({ data: subTags });
};
