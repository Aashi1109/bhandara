import config from "@/config";
import { Queue } from "bullmq";

export const VIDEO_QUEUE_NAME = "video-processing";

export const videoQueue = new Queue(VIDEO_QUEUE_NAME, {
  connection: {
    host: config.redis.default.url.replace("https://", ""),
    password: config.redis.default.token,
    tls: {},
    port: 6379,
  },
});

export const addVideoJob = async (mediaId: string, eventId: string) => {
  await videoQueue.add("process", { mediaId, eventId });
};
