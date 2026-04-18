import cors from 'cors';
import express from 'express';
import cookieparser from 'cookie-parser';
import swaggerUI from 'swagger-ui-express';

import helmet from 'helmet';
import config from '@/config';
import { errorHandler, morganLogger, requestContextMiddleware, requestMetrics } from '@/middlewares';
import appRoutes from '@/routes';
import { NotFoundError } from '@/exceptions';
import { swaggerSpec } from '@/docs/swagger';

import * as Sentry from '@sentry/node';
import * as HyperDX from '@hyperdx/node-opentelemetry';

const createServer = () => {
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

  // routes setup

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

  app.get('/', (req, res) => {
    res.send({
      name: 'Zentry API',
      description: 'Zentry backend service',
      version: '1.0.0',
    });
  });

  app.use(requestMetrics);
  app.use(requestContextMiddleware);

  app.use('/api', appRoutes);

  Sentry.setupExpressErrorHandler(app);
  HyperDX.setupExpressErrorHandler(app);

  app.use((req, res, next) => {
    next(new NotFoundError(`path not found: ${req.originalUrl}`));
  });

  app.use(errorHandler);

  return app;
};

export default createServer;
