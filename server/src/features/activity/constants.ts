export const ACTIVITY_TABLE_NAME = "Activities";

export enum EActivityVisibility {
  Public = "public",
  Private = "private",
}

export enum EActivityEntityType {
  Event = "event",
  Message = "message",
  Thread = "thread",
  Reaction = "reaction",
  Achievement = "achievement",
  User = "user",
  System = "system",
}

export enum EActivityType {
  EventCreated = "event.created",
  EventJoined = "event.joined",
  EventLeft = "event.left",
  EventVerified = "event.verified",
  MessageCreated = "message.created",
  ReactionCreated = "reaction.created",
  AchievementUnlocked = "achievement.unlocked",
}
