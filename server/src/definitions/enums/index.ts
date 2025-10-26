export enum EMessageType {
  PlainText = "text",
  // Rich Object can have images, images + text, for now
  RichObject = "rich_object",
}

export enum EEventType {
  Organized = "organized",
  Custom = "custom",
}

export enum EMediaProvider {
  Local = "local",
  S3 = "s3",
  GCS = "gcs",
  Cloudinary = "cloudinary",
  Supabase = "supabase",
}

export enum EMediaType {
  Image = "image",
  Video = "video",
  Audio = "audio",
  Document = "document",
}

export enum EEventStatus {
  Draft = "draft",
  Upcoming = "upcoming",
  Ongoing = "ongoing",
  Completed = "completed",
  Cancelled = "cancelled",
}

export enum EThreadType {
  Discussion = "discussion",
  QnA = "qna",
}

export enum EAccessLevel {
  Public = "public",
  Private = "private",
  Restricted = "restricted",
}

export enum EAuthProvider {
  Google = "google",
  Email = "email",
}

export enum EEventParticipantStatus {
  Pending = "pending",
  Confirmed = "confirmed",
  Declined = "declined",
}
