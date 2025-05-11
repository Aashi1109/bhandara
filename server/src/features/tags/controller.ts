import { ICustomRequest, IRequestPagination, ITag } from "@definitions/types";
import { Response } from "express";
import TagsService from "./service";
import { pick } from "@utils";
import { formQueryFromObject } from "@features/helpers";

const tagsService = new TagsService();

export const getTags = async (
  req: ICustomRequest & IRequestPagination,
  res: Response
) => {
  const { eventId, createdBy } = req.query;

  const query = formQueryFromObject<ITag>({ eventId, createdBy });

  const tags = await tagsService.getAll({ query }, req.pagination);
  return res.status(200).json(tags);
};

export const createTag = async (req: ICustomRequest, res: Response) => {
  const createData = pick(req.body, ["name", "value", "description"]);
  const tag = await tagsService.create(createData);
  return res.status(201).json(tag);
};

export const getTagById = async (req: ICustomRequest, res: Response) => {
  const { tagId } = req.params;
  const tag = await tagsService.getById(tagId);

  return res.status(200).json(tag);
};

export const updateTag = async (req: ICustomRequest, res: Response) => {
  const { tagId } = req.params;
  const updateData = pick(req.body, ["name", "value", "description"]);
  const tag = await tagsService.update(tagId, updateData);

  return res.status(200).json(tag);
};

export const deleteTag = async (req: ICustomRequest, res: Response) => {
  const { tagId } = req.params;
  const tag = await tagsService.delete(tagId);

  return res.status(200).json(tag);
};
