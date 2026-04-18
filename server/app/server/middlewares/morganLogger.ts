import { logger } from '@/src/common';
import morgan from 'morgan';

const stream = {
  // Use the http severity
  write: (message: string) => logger.http(message),
};

const skip = () => false;

// Redact sensitive query parameters (e.g. token) from logged URLs
morgan.token('safe-url', (req) => {
  try {
    const base = `http://localhost${req.url}`;
    const url = new URL(base);
    if (url.searchParams.has('token')) {
      url.searchParams.set('token', '[REDACTED]');
    }
    return url.pathname + (url.search || '');
  } catch {
    return req.url ?? '';
  }
});

const morganMiddleware = morgan(':remote-addr :method :safe-url :status :res[content-length] - :response-time ms', {
  stream,
  skip,
});

export default morganMiddleware;
