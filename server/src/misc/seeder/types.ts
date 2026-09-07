export type NumberRange = {
  min: number;
  max: number;
};

export type SeedOptions = {
  users: NumberRange;
  eventsPerUser: NumberRange;
  threadsPerEvent: NumberRange;
  messagesPerThread: NumberRange;
  totalEvents?: number;
  totalThreads?: number;
  totalMessages?: number;
  reuseExistingUsers?: boolean;
  reuseMaxUsers?: number;
  seedWorkers?: number;
  password: string;
  emailPrefix: string;
  tagsPerEvent: NumberRange;
};

export type SeedStats = {
  usersCreated: number;
  eventsCreated: number;
  threadsCreated: number;
  messagesCreated: number;
  reactionsCreated: number;
  savesCreated: number;
  achievementsCreated: number;
  activitiesCreated: number;
};

export type UserMetrics = {
  eventCreated: number;
  messageCreated: number;
  reactionCreated: number;
  streakCurrent: number;
  streakLongest: number;
};

export type SeededUserRow = {
  id: string;
  email: string;
  name: string;
};

export type SeedCoordinatorUser = SeededUserRow & {
  source: 'existing' | 'created';
};

export type SeededAuthUser = {
  authUserId: string;
  email: string;
  password: string;
  name: string;
  gender: string;
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  expiresIn: number;
};

export type SeederWorkerPayload = {
  options: SeedOptions;
  assignedUsers: SeedCoordinatorUser[];
  allUsers: SeedCoordinatorUser[];
  tagIds: string[];
  workerIndex: number;
  totalWorkers: number;
};
