import { ICustomRequest, IRequestPagination, ITag } from "@/definitions/types";
import { Response } from "express";
import TagsService from "./service";
import { pick } from "@/utils";

const tagsService = new TagsService();

export const getTags = async (
  req: ICustomRequest & IRequestPagination,
  res: Response
) => {
  const { eventId, createdBy, rootOnly } = req.query;

  if (rootOnly) {
    const rootTags = await tagsService.getRootTags();
    return res.status(200).json({ data: rootTags });
  }

  const where: Record<string, string> = {};
  if (eventId) where.eventId = eventId as string;
  if (createdBy) where.createdBy = createdBy as string;

  const tags = await tagsService.getAll({ where }, req.pagination);
  return res.status(200).json({ data: tags });
};

export const createTag = async (req: ICustomRequest, res: Response) => {
  const createData = pick(req.body, ["name", "value", "description"]);
  const tag = await tagsService.create(createData);
  return res.status(201).json({ data: tag });
};

export const getTagById = async (req: ICustomRequest, res: Response) => {
  const { tagId } = req.params;
  const tag = await tagsService.getById(tagId);

  return res.status(200).json({ data: tag });
};

export const updateTag = async (req: ICustomRequest, res: Response) => {
  const { tagId } = req.params;
  const updateData = pick(req.body, ["name", "value", "description"]);
  const tag = await tagsService.update(tagId, updateData);

  return res.status(200).json({ data: tag });
};

export const deleteTag = async (req: ICustomRequest, res: Response) => {
  const { tagId } = req.params;
  const tag = await tagsService.delete(tagId);

  return res.status(200).json({ data: tag });
};

export const getSubTags = async (req: ICustomRequest, res: Response) => {
  const { tagId } = req.params;
  const subTags = await tagsService.getSubTags(tagId);

  return res.status(200).json({ data: subTags });
};
