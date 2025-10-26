import { WORKER_CONNECTION_CONFIG } from "@/config";
import { Queue } from "bullmq";

export const VIDEO_QUEUE_NAME = "video-processing";

export const videoQueue = new Queue(VIDEO_QUEUE_NAME, {
  connection: WORKER_CONNECTION_CONFIG,
});

export const addVideoJob = async (mediaId: string, eventId: string) => {
  await videoQueue.add("process", { mediaId, eventId });
};
