import type { IAddress, ITag } from "@/definitions/types";

export interface IFormData {
  firstName: string;
  lastName: string;
  email: string;
  password: string;
  verifyPassword?: string;
  profilePic?: {
    url: string;
  };
  username?: string;
  tags?: ITag[];
  location?: IAddress | undefined;
  _location?: string;
  interests?: ITag[];
  gender?: string;
}
