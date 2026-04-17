import Ajv, { type ValidateFunction } from 'ajv';
import addFormats from 'ajv-formats';
import addErrors from 'ajv-errors';
import { type NextFunction, type Request, type Response } from 'express';
import { BadRequestError } from '@/exceptions';

const ajv = new Ajv({
  allErrors: true,
  strict: false,
  coerceTypes: false,
  useDefaults: true,
  removeAdditional: false,
});

addFormats(ajv);
addErrors(ajv);

const validatorCache: Record<string, ValidateFunction> = {};

function compileSchema(schemaName: string, schema: object): ValidateFunction {
  if (!validatorCache[schemaName]) {
    validatorCache[schemaName] = ajv.compile(schema);
  }
  return validatorCache[schemaName];
}

function buildErrorMessage(validate: ValidateFunction): string {
  return (validate.errors || [])
    .map((err) => {
      const path = err.instancePath || '/';
      const { keyword } = err;
      const msg = err.message || 'Validation error';

      switch (keyword) {
        case 'required':
          return `Missing required property "${(err.params as any).missingProperty}" at ${path}`;
        case 'additionalProperties':
          return `Unexpected property "${(err.params as any).additionalProperty}" at ${path}`;
        case 'type':
          return `Invalid type at ${path}, expected ${(err.params as any).type}`;
        case 'enum':
          return `Invalid value at ${path}, expected one of ${(err.params as any).allowedValues.join(', ')}`;
        case 'minLength':
          return `String at ${path} is too short (minLength: ${(err.params as any).limit})`;
        case 'maxLength':
          return `String at ${path} is too long (maxLength: ${(err.params as any).limit})`;
        case 'minimum':
        case 'maximum':
          return `Value at ${path} must be ${keyword} ${(err.params as any).limit}`;
        default:
          return `${path} ${msg}`;
      }
    })
    .join(', ');
}

/**
 * Returns a dual-mode validator:
 * - As Express middleware: validateFn(req, res, next) — validates req.body, sets req.body = validData, calls next()
 * - As data validator:     validateFn(data, callback) — validates data directly, calls callback(validData)
 */
export const validateSchema = (schemaName: string, schema: object) => {
  const validate = compileSchema(schemaName, schema);

  function validator(req: Request, res: Response, next: NextFunction): void;
  function validator<T, R>(data: T, callback: (validData: T) => R): R;
  function validator(reqOrData: any, resOrCallback: any, next?: NextFunction): any {
    if (typeof next === 'function') {
      // Middleware mode — validate req.body
      const isValid = validate(reqOrData.body);
      if (!isValid) throw new BadRequestError(buildErrorMessage(validate));
      next();
    } else {
      // Data validator mode — validate plain data
      const isValid = validate(reqOrData);
      if (!isValid) throw new BadRequestError(buildErrorMessage(validate));
      return resOrCallback(reqOrData);
    }
  }

  return validator;
};

export default ajv;
