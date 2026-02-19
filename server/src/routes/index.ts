import { getDirectories, getRouteFiles } from "@/helpers/file";
import express from "express";
const router = express.Router();

const routeDirectories = getDirectories(__dirname);
const routeFiles = getRouteFiles(__dirname);

const isDev = process.env.NODE_ENV !== "production";

for (const dir of routeDirectories) {
  import(`./${dir}/index.${isDev ? "ts" : "js"}`).then((m) => {
    router.use(`/${dir}`, m.default);
  });
}

for (const file of routeFiles) {
  import(`./${file}`).then((m) => {
    const routePath = file.split(".")[0];
    router.use(routePath === "root" ? "/" : `/${routePath}`, m.default);
  });
}

export default router;
