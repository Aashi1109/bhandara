import type { Request } from 'express';
import type {
  EAccessLevel,
  EEventParticipantStatus,
  EEventStatus,
  EEventType,
  EMediaProvider,
  EMediaType,
} from '@/common/definitions/enums';

// Base Interface for Timestamps
export interface PaginatedResult<T> {
  items: T[];
  pagination: IPaginationParams;
}

export interface ITimeStamp {
  createdAt: Date;
  updatedAt: Date;
}

// Base User Interface
export interface IBaseUser extends ITimeStamp {
  id: string;
  name: string;
  email: string;
  __sid?: string | null;
  gender: string;
  address: Record<string, any> | null;
  isVerified: boolean;
  password: string | null;
  meta: Record<string, any>;
  profilePic: Record<string, any> | null;
  mediaId: string | null | IMedia;
  bio?: string | null;
  username?: string;
  media?: IMedia;
}

// Message Content Type
export type IMessageContent = {
  text?: string; // Optional caption
  media?: IMedia[] | string[]; // Array of media IDs
  links?: { url: string; title: string }[]; // Array of links with titles
};

// Message Interface
export interface IMessage extends ITimeStamp {
  id: string;
  userId: string;
  parentId: string | null;
  content: IMessageContent;
  isEdited: boolean;
  threadId: string;
  stats?: IMessageStats;
  user?: IBaseUser;
  reactions?: IReaction[];
}

// Thread Lock History
export interface ILockHistory {
  lockedBy: string; // ID of the user who locked the thread
  lockedAt: Date; // Timestamp of when the thread was locked
}

// Base Thread Interface
export interface IBaseThread extends ITimeStamp {
  id: string;
  visibility: EAccessLevel;
  lockHistory: ILockHistory[];
  parentId?: string | null;
  eventId: string;
  stats?: IThreadStats;
  messages?: IMessage[];

  createdBy: string;
  creator: IBaseUser;
}

// Location Interface
export interface ILocation {
  address?: string;
  latitude?: number;
  longitude?: number;
  venue?: string | null;
  coordinates?: {
    latitude?: number;
    longitude?: number;
  };
  [key: string]: any;
}

// Event Participant Interface
export interface IParticipant {
  user: string | IBaseUser;
  status: EEventParticipantStatus;
}

// Event Interface
export interface IEvent extends ITimeStamp {
  id: string;
  name: string;
  description: string;
  location: ILocation;
  participants: IParticipant[]; // JSONB field
  verifiers: IVerifier[]; // Array of verifier IDs
  type: EEventType;
  visibility: EAccessLevel;
  createdBy: string; // References "User" table
  creator?: IBaseUser;
  status: EEventStatus;
  isDraft: boolean;
  cancelledAt: Date | string | null;
  capacity: number;
  tags: ITag[] | string[]; // Array of tag IDs
  media: IMedia[] | string[]; // Array of media IDs
  stats?: IEventStats;
  reactions?: IReaction[];
  startTime: Date | string;
  endTime: Date | string;
}

export interface IEventStats {
  reactionCount: number;
  threadCount: number;
  participantCount: number;
  verifierCount: number;
  mediaCount: number;
  tagCount: number;
  viewCount?: number;
  ratingCount?: number;
  ratingAverage?: number;
}

export interface IThreadStats {
  reactionCount: number;
  messageCount: number;
  viewCount?: number;
  ratingCount?: number;
  ratingAverage?: number;
}

export interface IMessageStats {
  reactionCount: number;
  replyCount: number;
  viewCount?: number;
  ratingCount?: number;
  ratingAverage?: number;
}

export interface IEntityRatingHistogram {
  '1': number;
  '2': number;
  '3': number;
  '4': number;
  '5': number;
}

export interface IEntityEngagementStats {
  viewCount: number;
  ratingCount: number;
  ratingAverage: number;
  ratingHistogram: IEntityRatingHistogram;
}

export interface IEntityEngagementSummary extends IEntityEngagementStats {
  currentUserRating: number | null;
  currentUserReview: string | null;
  currentUserReviewedAt: Date | string | null;
}

export interface IEntityEngagement extends ITimeStamp {
  id: string;
  entityType: string;
  entityId: string;
  stats: IEntityEngagementStats;
}

export interface IEntityRating extends ITimeStamp {
  id: string;
  entityType: string;
  entityId: string;
  userId: string;
  value: number;
  review?: string | null;
  user?: IBaseUser;
}

export interface ISavedEntity extends ITimeStamp {
  id: string;
  userId: string;
  entityType: 'event' | 'thread' | 'message' | 'user';
  entityId: string;
}

export interface IEntitySaveSummary {
  entityType: ISavedEntity['entityType'];
  entityId: string;
  saved: boolean;
  saveCount: number;
  savedAt: Date | string | null;
}

export interface ISavedEntityListItem extends ISavedEntity {
  entity: IEvent | IBaseThread | IMessage | IBaseUser | null;
}

export interface IVerifier {
  user: string | IBaseUser;
  verifiedAt: Date | string;
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
}

// Media Storage Interface
interface IMediaStorage {
  bucket: string;
  metadata: Record<string, any>;
}

export interface IMediaThumbnails {
  sm: string;
  md: string;
  xl: string;
}

// Media Interface
export interface IMedia extends ITimeStamp {
  id: string;
  type: EMediaType;
  provider: EMediaProvider;
  url: string;
  publicUrl?: string;
  publicUrlExpiresAt?: Date | number;
  caption?: string | null;
  thumbnail?: string | null;
  thumbnails?: IMediaThumbnails | null;
  variants?: IMediaThumbnails | null;
  streamUrl?: string | null;
  size?: number | null;
  mimeType?: string | null;
  duration?: number | null;
  uploader: string; // References "User" table
  storage: IMediaStorage;
  access: EAccessLevel;
  metadata: Record<string, any>;

  path?: string;
  name: string;
}

export interface IMediaEventJunction extends ITimeStamp {
  eventId: string;
  mediaId: string;
}

export interface IReaction extends ITimeStamp {
  id: string;
  contentId: string;
  emoji: string;
  userId: string;
  user?: IBaseUser;
}

export interface IActivity extends ITimeStamp {
  id: string;
  actorId: string;
  recipientId?: string | null;
  type: string;
  entityType: string;
  entityId: string;
  payload: Record<string, any>;
  visibility: 'public' | 'private';
  readAt?: Date | null;
  actor?: IBaseUser | null;
  recipient?: IBaseUser | null;
}

export interface IUserAchievement extends ITimeStamp {
  id: string;
  userId: string;
  key: string;
  title: string;
  description: string;
  icon?: string | null;
  metadata: Record<string, any>;
  unlockedAt: Date;
}

export interface IAchievementProgress extends ITimeStamp {
  id: string;
  userId: string;
  metrics: Record<string, any>;
}

export interface IPaginationParams {
  limit: number;
  next: string | null;
  hasNext?: boolean;
  total?: number;
  sortBy: 'createdAt' | 'updatedAt';
  sortOrder: 'asc' | 'desc';
  startDate?: Date;
  endDate?: Date;
}

export interface ICustomRequest extends Request {
  user: IBaseUser;
  session: IUserSession;
}

export interface IUserSession {
  location: Record<string, any>;
  userAgent: {
    device: {
      model: string;
      vendor: string;
    };
    os: {
      name: string;
      version: string;
    };
    browser: {
      name: string;
      version: string;
    };
    ua: string;
  };
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  expiresIn: number;
  user: { id: string };
}

export interface IRequestPagination extends Request {
  pagination: IPaginationParams;
}
