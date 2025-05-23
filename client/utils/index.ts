export const jnstringify = (payload: any) => JSON.stringify(payload);
export const jnparse = (payload: any) => JSON.parse(payload);

export const pick = <T extends Record<string, any>, K extends keyof T>(obj: T, keys: K[]) => {
  return keys.reduce(
    (acc, key) => {
      if (obj[key] !== undefined) {
        acc[key] = obj[key];
      }
      return acc;
    },
    {} as Pick<T, K>
  );
};

export const omit = <T extends Record<string, any>, K extends keyof T>(obj: T, keys: K[]) => {
  const newObj = { ...obj };
  keys.forEach((key) => {
    delete newObj[key];
  });
  return newObj;
};

export const isEmpty = (value: any) => {
  if (value === null || value === undefined) return true;
  if (typeof value === "string") return value.trim() === "";
  if (Array.isArray(value)) return value.length === 0;
  if (typeof value === "object") return Object.keys(value).length === 0;
  return false;
};

export const startCase = (str: string) => {
  if (!str) return "";

  return str
    .replace(/[_-]/g, " ") // Replace hyphens and underscores with spaces
    .replace(/([A-Z])/g, " $1") // Add space before capital letters
    .replace(/^./, (str) => str.toUpperCase()) // Capitalize first letter
    .trim() // Remove leading/trailing spaces
    .replace(/\s+/g, " "); // Replace multiple spaces with single space
};
