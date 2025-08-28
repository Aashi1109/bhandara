import { get32BitMD5Hash, getAlphaNumericId } from "@/helpers";

export function getUniqueFilename(path: string) {
  const match = path.match(/^(.*\/)([^/]+?)(\.[^.]+)?$/);
  if (!match) return path;

  const [, dir, filename, ext = ""] = match;
  const id = getAlphaNumericId(10);
  const newFilename = `${filename}-${id}${ext}`;

  // Step 2: Generate hash *including* the extension
  const hash = get32BitMD5Hash(newFilename);

  // Step 3: Return new path with only the hash
  return `${dir}${hash}`;
}
