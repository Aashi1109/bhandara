import { getDirectories, getRouteFiles } from "@/helpers/file";
import express from "express";
const router = express.Router();

const routeDirectories = getDirectories(import.meta.url);
const routeFiles = getRouteFiles(import.meta.url);

const isDev = process.env.NODE_ENV !== "production";

for (const dir of routeDirectories) {
  const m = await import(`./${dir}/index.${isDev ? "ts" : "js"}`);
  router.use(`/${dir}`, m.default);
}

for (const file of routeFiles) {
  const routePath = file.split(".")[0];

  const m = await import(`./${file}`);
  router.use(routePath === "root" ? "/" : `/${routePath}`, m.default);
}

export default router;
