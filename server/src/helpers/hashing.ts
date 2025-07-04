import MD5 from "crypto-js/md5";

/**
 * Return the 32‑bit MD5 hash of the provided value.
 * @param value The string to hash.
 */
export const get32BitMD5Hash = (value: string) => MD5(value).toString();
