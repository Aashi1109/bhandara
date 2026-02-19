import type { ITag } from "@/definitions/types";
import axiosClient from "./base";

export const getAllTags = async (): Promise<{
  data?: ITag[];
  error: string | null;
}> => {
  const response = await axiosClient.get("/tags?rootOnly=true");
  return response.data;
};

export const getSubTags = async (
  parentId: string
): Promise<{
  data?: ITag[];
  error: string | null;
}> => {
  const response = await axiosClient.get(`/tags/${parentId}/sub-tags`);
  return response.data;
};
