import config from "@/config";
import Redis from "ioredis";
// import { Redis } from "@upstash/redis";

// // Initiate Redis instance by connecting to REST URL
// export const redis = new Redis({
//   url: config.redis.url,
//   token: config.redis.token,
// });

const redis = new Redis({
  maxRetriesPerRequest: null,
  host: config.redis.host,
  port: +config.redis.port,
  password: config.redis.password,
});

export default redis;
