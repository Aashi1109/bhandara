import { createLogger, format, transports } from 'winston';
import 'winston-daily-rotate-file';
import * as HyperDX from '@hyperdx/node-opentelemetry';
import config from '../config';
import errors = format.errors;

const customFormat = format.printf(({ level, message, timestamp, service, stack }) => {
  return JSON.stringify({
    asctime: timestamp,
    level: level.toUpperCase(),
    service,
    message,
    stack,
  });
});

const fileFormat = format.combine(
  format.splat(),
  format.json(),
  errors({ stack: true }),
  format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  customFormat,
);

const allLogsTransport = new transports.DailyRotateFile({
  filename: config.log.allLogsPath.replace('.log', '-%DATE%.log'),
  datePattern: 'YYYY-MM-DD',
  maxFiles: '1d',
  maxSize: '20m',
  zippedArchive: true,
  format: fileFormat,
});

const errorLogsTransport = new transports.DailyRotateFile({
  filename: config.log.errorLogsPath.replace('.log', '-%DATE%.log'),
  datePattern: 'YYYY-MM-DD',
  maxFiles: '1d',
  maxSize: '20m',
  zippedArchive: true,
  level: 'error',
  format: fileFormat,
});

const logger = createLogger({
  level: 'http',
  defaultMeta: { service: config.infrastructure.serviceName },
  format: format.combine(format.splat(), errors({ stack: true }), format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' })),
  transports: [
    allLogsTransport,
    errorLogsTransport,
    new transports.Console({
      format: format.combine(
        format.colorize({ all: true }),
        format.printf(({ level, message, timestamp, service }) => {
          return `${timestamp} [${service}] ${level}: ${message}`;
        }),
      ),
    }),
    HyperDX.getWinstonTransport('info', {
      detectResources: true,
      service: config.infrastructure.serviceName,
    }),
  ],
  exitOnError: false,
});

export default logger;
