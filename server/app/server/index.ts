import http from 'http';

import express, { type Express } from 'express';
import cors from 'cors';
import cookieparser from 'cookie-parser';
import swaggerUI from 'swagger-ui-express';

import helmet from 'helmet';
import { errorHandler, morganLogger, requestContextMiddleware, requestMetrics } from './middlewares';
import appRoutes from './routes';
import { swaggerSpec } from './docs/swagger';

import * as Sentry from '@sentry/node';
import { config, logger, NotFoundError } from '@/src/common';
import * as HyperDX from '@hyperdx/node-opentelemetry';
import { initializeSocket } from '@/src/socket';
import { initializeMediaRealtime } from '@/src/supabase/realtime';

export function createServer(): Express {
  const app = express();

  // trust one proxy hop so req.ip resolves correctly behind load balancers
  app.set('trust proxy', 1);

  // cors setup to allow requests from the frontend only for now
  app.use(helmet());
  app.use(cors(config.corsOptions));

  // parse requests of content-type - application/json
  // rawBody is captured for webhook signature verification
  app.use(
    express.json({
      limit: config.express.fileSizeLimit,
      verify: (req: any, _res, buf) => {
        req.rawBody = buf.toString('utf8');
      },
    }),
  );
  // parse requests of content-type - application/x-www-form-urlencoded
  app.use(
    express.urlencoded({
      extended: true,
      limit: config.express.fileSizeLimit,
    }),
  );

  app.use(morganLogger);
  app.use(cookieparser(process.env.COOKIE_SECRET));

  // swagger docs
  app.use(
    '/docs',
    swaggerUI.serve,
    swaggerUI.setup(swaggerSpec, {
      swaggerOptions: {
        withCredentials: true,
        persistAuthorization: true,
      },
    }),
  );

  app.get('/', (_req, res) => {
    res.send({
      name: 'Zentry API',
      description: 'Zentry backend service',
      version: '1.0.0',
    });
  });

  app.use('/api', requestMetrics, requestContextMiddleware, appRoutes);

  Sentry.setupExpressErrorHandler(app);
  HyperDX.setupExpressErrorHandler(app);

  app.use((req, _res, next) => {
    next(new NotFoundError(`path not found: ${req.originalUrl}`));
  });

  app.use(errorHandler);

  return app;
}

export default function run(_appName: string) {
  const app = createServer();
  const httpServer = http.createServer(app);

  initializeSocket(httpServer);
  initializeMediaRealtime();

  httpServer.listen(config.port, () => {
    logger.info(`Server is running on port ${config.port}`);
  });
}
