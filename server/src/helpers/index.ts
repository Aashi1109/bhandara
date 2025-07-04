import config from "@config";
import { IBaseUser } from "@definitions/types";
import logger from "@logger";
import { jnstringify } from "@utils";
import * as bcrypt from "bcrypt";
import * as jwt from "jsonwebtoken";
import { nanoid } from "nanoid";
import { v7 as uuidv7 } from "uuid";

/**
 * Hashes a password using bcrypt.
 * @param {string} password - The password to hash.
 * @returns {Promise<{[string:string]}>} A Promise that resolves with the hashed password.
 * @throws {Error} Throws an error if hashing fails.
 */
export const hashPassword = async (password: string): Promise<string> => {
  try {
    const salt = await bcrypt.genSalt(config.saltRounds);
    const hashedPassword = await bcrypt.hash(password, salt);
    return hashedPassword;
  } catch (error) {
    console.error(error);
    throw new Error("Failed to hash password");
  }
};

/**
 * Generates an access token for the given user.
 * @param {IBaseUser} user - The user for whom the access token is generated.
 * @returns {Promise<string>} A Promise that resolves with the generated access token.
 * @throws {Error} Throws an error if token generation fails.
 */
export const signJWTPayload = async (user: IBaseUser): Promise<string> => {
  try {
    const payload = {
      email: user.email,
      id: user.id,
    };
    return jwt.sign(payload, config.jwt.secret, {
      expiresIn: config.jwt.expiresIn as jwt.SignOptions["expiresIn"],
    });
  } catch (error) {
    throw new Error("Failed to generate access token");
  }
};

/**
 * Validates a password by comparing it with its hashed counterpart.
 * @param {string} originalPassword - The original (hashed) password to compare against.
 * @param {string} comparePassword - The password to compare.
 * @returns {Promise<boolean>} A Promise that resolves with a boolean indicating whether the passwords match.
 * @throws {Error} Throws an error if the comparison fails.
 */
export const validatePassword = async (
  originalPassword: string,
  comparePassword: string
): Promise<boolean> => {
  try {
    return await bcrypt.compare(comparePassword, originalPassword);
  } catch (error) {
    logger.error(`Error validating password: ${error}`);
    throw new Error("Failed to validate password");
  }
};

/**
 * Decode a JWT token and return its payload.
 * @param rawToken The token string prefixed with type.
 */
export const getJWTPayload = async (rawToken: string) => {
  const jwtPayload = <any>(
    jwt.verify(rawToken?.split(" ")[0], config.jwt.secret, { complete: true })
  );

  return jwtPayload.payload;
};

/**
 * Build a filter object containing only non-empty values.
 */
export const createFilterFromParams = (params: Record<string, any>) => {
  return Object.entries(params).reduce((acc, [key, value]) => {
    if (value !== undefined && value !== null && value !== "") {
      acc[key] = value;
    }
    return acc;
  }, {} as Record<string, any>);
};

interface RetryConfig {
  maxAttempts?: number;
  delayMs?: number;
  maxDelayMs?: number;
  silent?: boolean;
}

/**
 * Wrap an async function with retry logic using exponential backoff.
 */
export const withRetry =
  <T, Args extends any[]>(config: RetryConfig = {}) =>
  (fn: (...args: Args) => Promise<T>) =>
  async (...args: Args): Promise<T> => {
    const { maxAttempts = 3, delayMs = 1000, maxDelayMs = 10000 } = config;

    let attempt = 1;

    while (true) {
      try {
        const result = await fn(...args);
        if (attempt > 1) {
          logger.debug(`Succeeded after ${attempt} attempts`);
        }
        return result;
      } catch (error) {
        logger.error(`Error in withRetry`, error);
        if (attempt === maxAttempts) {
          logger.error(
            `Failed after ${maxAttempts} attempts ${jnstringify(error)}`
          );
          throw error;
        }

        const delay = Math.min(Math.pow(2, attempt - 1) * delayMs, maxDelayMs);
        logger.warn(
          `Attempt ${attempt}/${maxAttempts} failed. Retrying in ${delay}ms...`
        );

        await new Promise((resolve) => setTimeout(resolve, delay));
        attempt++;
      }
    }
  };

export * from "./validation";
export { default as ajv } from "./validation";

/**
 * Retrieve geo location data for an IP address using ip2location.
 */
export const getGeoLocationData = async (ip: string) => {
  const skippedIps = ["127.0.0.1", "::1", "localhost"];
  // Return null for localhost IPs
  if (skippedIps.includes(ip)) {
    return null;
  }
  const response = await fetch(
    `https://api.ip2location.io/?key=${config.ip2location.apiKey}&ip=${ip}`
  );
  const data = await response.json();

  if (data?.error) {
    logger.error(`Error getting geo location data: ${data.error}`);
    return {};
  }

  return {
    city: data.city_name,
    country: data.country_name,
    region: data.region_name,
    latitude: data.latitude,
    longitude: data.longitude,
    timezone: data.time_zone,
  };
};

/**
 * Generate a random alphanumeric ID of the given size.
 */
export const getAlphaNumericId = (size: number = 21) => {
  return nanoid(size);
};

/** Return a new UUIDv7 value. */
export const getUUIDv7 = () => uuidv7();

/**
 * Compute the distance in meters between two latitude/longitude pairs.
 */
export function getDistanceInMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
) {
  const toRad = (x: number) => (x * Math.PI) / 180;
  const R = 6371000; // Earth radius in meters
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

export * from "./hashing";
