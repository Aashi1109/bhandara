import {
  EAccessLevel,
  EEventParticipantStatus,
  EEventStatus,
  EEventType,
  EMediaProvider,
  EMediaType,
  EThreadType
} from "@/definitions/enums";

// Base Interface for Timestamps
export interface ITimeStamp {
  createdAt: Date; // Always present
  updatedAt: Date; // Always present
  deletedAt?: Date | null; // Soft delete column
}

// Base User Interface
export interface IBaseUser extends ITimeStamp {
  id: string;
  name: string;
  email: string;
  gender: string;
  address: Record<string, any> | null; // JSONB field
  isVerified: boolean;
  password: string | null;
  meta: Record<string, any>;
  profilePic: {
    url: string;
  } | null;
  mediaId: string | null | IMedia;
  username?: string;
  media?: IMedia;
  bio?: string;
}

// Message Content Type
export type IMessageContent = {
  text?: string; // Optional caption
  media?: IMedia[] | string[]; // Array of media IDs
  links?: { url: string; title: string }[]; // Array of links with titles
}; // Rich object message

export interface IReaction extends ITimeStamp {
  id: string;
  contentId: string;
  emoji: string;
  userId: string;
  user?: IBaseUser;
}

// Message Interface
export interface IMessage extends ITimeStamp {
  id: string;
  userId: string;
  parentId: string | null;
  content: IMessageContent;
  isEdited: boolean;
  threadId: string;
  children: IPaginatedDataResponse<IMessage>;
  user?: IBaseUser;
  reactions: IReaction[];
}

export interface IPaginatedDataResponse<T> {
  items: T[] | undefined;
  pagination: IPaginationResponse;
}

// Thread Lock History
export interface ILockHistory {
  lockedBy: string; // ID of the user who locked the thread
  lockedAt: Date; // Timestamp of when the thread was locked
}

// Base Thread Interface
export interface IBaseThread extends ITimeStamp {
  id: string;
  type: EThreadType;
  status: EAccessLevel;
  visibility: EAccessLevel;
  lockHistory: ILockHistory[];
  eventId: string;
  messages?: IMessage[];
  user?: IBaseUser;
}

// Event Participant Interface
interface IParticipant {
  user: string | IBaseUser;
  status: EEventParticipantStatus;
}

// Event Interface
export interface IEvent extends ITimeStamp {
  id: string;
  name: string;
  description: string;
  location: IAddress; // JSONB field
  participants: IParticipant[]; // JSONB field
  verifiers: { user: string | IBaseUser; verifiedAt: Date | string }[]; // Array of verifier IDs
  type: EEventType;
  createdBy: string; // References "User" table
  creator: IBaseUser;
  status: EEventStatus;
  capacity: number;
  tags: ITag[]; // Array of tag IDs
  media: IMedia[]; // Array of media IDs
  timings: { start: Date; end: Date };
}

// Tag Interface
export interface ITag extends ITimeStamp {
  id: string;
  name: string;
  value: string; // Normalized tag name, always unique
  description?: string | null;
  icon?: string | null;
  color?: string | null;
  parentId?: string | null; // References "Tag" table
  createdBy?: string | null; // References "User" table
  eventId?: string | null; // References "Event" table
  subTags?: ITag[];
  hasChildren?: boolean;
}

// Media Storage Interface
interface IMediaStorage {
  provider: EMediaProvider;
  bucket: string;
  metadata: Record<string, any>;
}

// Media Interface
export interface IMedia extends ITimeStamp {
  id: string;
  type: EMediaType;
  url: string;
  publicUrl?: string;
  publicUrlExpiresAt?: Date;
  caption?: string | null;
  thumbnail?: string | null;
  size?: number | null;
  mimeType?: string | null;
  duration?: number | null;
  uploader: string; // References "User" table
  storage: IMediaStorage; // JSONB field
  accessLevel: EAccessLevel;
  metadata: Record<string, any>;
  name: string;

  path?: string;
}

export interface IMediaEventJunction extends ITimeStamp {
  eventId: string;
  mediaId: string;
}

export interface IPaginationResponse {
  limit: number;
  page: number;
  next: string | null;
  hasNext?: boolean;
  total?: number;
}

export interface IPaginationParams extends IPaginationResponse {
  sortBy: "createdAt" | "updatedAt";
  sortOrder: "asc" | "desc";
  startDate?: Date;
  endDate?: Date;
}

export interface IAddress {
  address: string;
  place: string;
  street: string;
  postcode: string;
  city: string;
  district: string;
  state: string;
  country: string;
  building?: string;
  latitude: number;
  longitude: number;
  landmark?: string;
}

export interface IBaseResponse<T> {
  data?: T;
  error?: any;
}

// Search Types
export interface ISearchFilters {
  types?: ('event' | 'user' | 'tag')[];
  eventStatus?: EEventStatus[];
  eventType?: EEventType[];
  dateRange?: {
    start: Date;
    end: Date;
  };
  location?: {
    latitude: number;
    longitude: number;
    radius: number; // in kilometers
  };
  tags?: string[];
  limit?: number;
  offset?: number;
}

export interface ISearchResult {
  id: string;
  type: 'event' | 'user' | 'tag';
  title: string;
  description?: string;
  imageUrl?: string;
  metadata: Record<string, any>;
  relevanceScore: number;
  createdAt: Date;
}
