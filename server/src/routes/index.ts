import { getDirectories, getRouteFiles } from "@/helpers/file";
import express from "express";
const router = express.Router();

const routeDirectories = getDirectories(__dirname);
const routeFiles = getRouteFiles(__dirname);

const isDev = process.env.NODE_ENV !== "production";

for (const dir of routeDirectories) {
  new Promise(async (resolve, reject) => {
    const m = await import(`./${dir}/index.${isDev ? "ts" : "js"}`);
    router.use(`/${dir}`, m.default);
    resolve(true);
  });
}

for (const file of routeFiles) {
  new Promise(async (resolve, reject) => {
    const routePath = file.split(".")[0];
    const m = await import(`./${file}`);
    router.use(routePath === "root" ? "/" : `/${routePath}`, m.default);
    resolve(true);
  });
}

export default router;
