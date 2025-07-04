import { readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

/** Resolve a module URL to an absolute file path. */
export const __filename = (url: string) => {
  return fileURLToPath(url);
};

/** Resolve the directory name for a module URL. */
export const __dirname = (url: string) => {
  return path.dirname(fileURLToPath(url));
};

/** Return the names of subdirectories at a given path. */
export const getDirectories = (source: string) =>
  readdirSync(__dirname(source), { withFileTypes: true })
    .filter((dirent) => dirent.isDirectory())
    .map((dirent) => dirent.name);

/** List route files within a directory. */
export const getRouteFiles = (source: string) =>
  readdirSync(__dirname(source), { withFileTypes: true })
    .filter((dirent) => !dirent.isDirectory() && dirent.name.includes("route"))
    .map((dirent) => dirent.name);

/** Return all file names within a directory. */
export const getDirectoryFiles = (source: string) =>
  readdirSync(__dirname(source), { withFileTypes: true })
    .filter((dirent) => !dirent.isDirectory())
    .map((dirent) => dirent.name);
