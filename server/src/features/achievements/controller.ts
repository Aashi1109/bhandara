import type { ICustomRequest } from '@/src/common/definitions/types';
import type { Response } from 'express';
import AchievementService from './service';

const achievementService = new AchievementService();

export const getUserAchievements = async (req: ICustomRequest, res: Response) => {
  const id = req.params.id as string;
  const items = await achievementService.getUserAchievements(id);

  return res.status(200).json({
    data: {
      items,
      definitions: achievementService.getDefinitions(),
    },
  });
};

export const getUserAchievementProgress = async (req: ICustomRequest, res: Response) => {
  const id = req.params.id as string;
  const data = await achievementService.getUserProgress(id);

  return res.status(200).json({
    data,
  });
};
