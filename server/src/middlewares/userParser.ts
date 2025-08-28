import { ICustomRequest } from "@/definitions/types";
import { NotFoundError } from "@/exceptions";
import { NextFunction, Response } from "express";
import asyncHandler from "./asyncHandler";

import {
  getSafeUser,
  getUserCache,
  MediaService,
  setUserCache,
  UserService,
} from "@/features";
import { isEmpty } from "@/utils";

const userService = new UserService();
const mediaService = new MediaService();

const userParser = async (
  req: ICustomRequest,
  res: Response,
  next: NextFunction
) => {
  let user = await getUserCache(req.session.user.id);

  if (!user) {
    const data = await userService.getById(req.session.user.id);
    if (isEmpty(data)) throw new NotFoundError("User not found");
    await setUserCache(req.session.user.id, data);
    user = data;
  }

  (req as ICustomRequest).user = getSafeUser(user);
  return next();
};

export default asyncHandler(userParser);
