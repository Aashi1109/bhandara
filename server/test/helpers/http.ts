import { IncomingMessage, ServerResponse } from 'node:http';
import { Socket } from 'node:net';
import type { Express } from 'express';
import { defaultSession, defaultUser } from '../mocks/external';

export const AUTH_COOKIE = 'bh_session=test-session';

export const authHeaders = {
  Cookie: AUTH_COOKIE,
};

export const createAuthenticatedSession = (overrides: Partial<typeof defaultSession> = {}) => ({
  ...defaultSession,
  ...overrides,
});

export const createAuthenticatedUser = (overrides: Partial<typeof defaultUser> = {}) => ({
  ...defaultUser,
  ...overrides,
});

type InvokeAppOptions = {
  body?: Record<string, unknown>;
  headers?: Record<string, string>;
  method?: string;
  url: string;
};

export const invokeApp = async (app: Express, { body, headers = {}, method = 'GET', url }: InvokeAppOptions) => {
  const socket = new Socket({ readable: true, writable: true });
  socket.write = () => true;
  socket.on = function on() {
    return this;
  };
  socket.removeListener = function removeListener() {
    return this;
  };
  socket.destroy = function destroy() {};

  const req = new IncomingMessage(socket as any);
  req.method = method;
  req.url = url;
  req.headers = Object.fromEntries(Object.entries(headers).map(([key, value]) => [key.toLowerCase(), value]));
  (req as any).socket = { remoteAddress: '127.0.0.1' };

  let payload = '';
  if (body !== undefined) {
    payload = JSON.stringify(body);
    req.headers['content-length'] = Buffer.byteLength(payload).toString();
    req.headers['content-type'] = 'application/json';
    (req as any).body = body;
  }

  const res = new ServerResponse(req);
  const bodyChunks: Buffer[] = [];
  const originalWrite = res.write.bind(res);
  const originalEnd = res.end.bind(res);
  let resolveEnd: (() => void) | null = null;
  const ended = new Promise<void>((resolve) => {
    resolveEnd = resolve;
  });

  res.write = ((chunk: any, ...args: any[]) => {
    if (chunk) bodyChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    return originalWrite(chunk, ...args);
  }) as typeof res.write;

  res.end = ((chunk: any, ...args: any[]) => {
    if (chunk) bodyChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    const result = originalEnd(chunk, ...args);
    resolveEnd?.();
    return result;
  }) as typeof res.end;

  res.assignSocket(socket as any);

  const done = new Promise<void>((resolve, reject) => {
    ended.then(resolve);
    res.on('error', reject);
    app.handle(req, res, (error: unknown) => {
      if (error) reject(error);
    });
  });

  process.nextTick(() => {
    req.push(payload || null);
    if (payload) req.push(null);
  });

  await done;

  const text = Buffer.concat(bodyChunks).toString('utf8');
  const contentType = res.getHeader('content-type');
  const parsedBody =
    typeof contentType === 'string' && contentType.includes('application/json') ? JSON.parse(text) : text;

  return {
    body: parsedBody,
    headers: res.getHeaders(),
    status: res.statusCode,
    text,
  };
};
