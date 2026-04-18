import CustomError from './CustomError';

export function createCustomErrorClass(
  className: string,
  defaultStatus: number = 500,
  defaultMessage: string,
): typeof CustomError {
  // Dynamically create a new class that extends CustomError
  class DynamicCustomError extends CustomError {
    /**
     * Creates a new instance of the custom error.
     * @constructor
     * @param {string} message - The error message.
     * @param {any} [additionalInfo=undefined] - Additional information about the error.
     * @param {number} [status=defaultStatus] - The HTTP status code associated with the error.
     */
    constructor(message: string = defaultMessage, additionalInfo: any = undefined, status: number = defaultStatus) {
      super(message, additionalInfo, status);
      this.name = className; // Set the name of the error class
    }
  }

  // Set the name of the class dynamically
  Object.defineProperty(DynamicCustomError, 'name', { value: className });

  return DynamicCustomError;
}

export const NotFoundError = createCustomErrorClass('NotFoundError', 404, 'Resource not found');
export const BadRequestError = createCustomErrorClass('BadRequestError', 400, 'Bad request');
export const UnauthorizedError = createCustomErrorClass('UnauthorizedError', 401, 'Unauthorized access');
export const ForbiddenError = createCustomErrorClass('ForbiddenError', 403, 'Forbidden access');

export class SupabaseCustomError extends Error {
  status: number;
  statusText: string;
  constructor(message: string, status: number, statusText: string) {
    super(message);
    this.status = status;
    this.statusText = statusText;
    this.name = statusText;
  }
}

export { default as CustomError } from './CustomError';
