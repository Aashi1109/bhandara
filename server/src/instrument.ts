// Import with `import * as Sentry from "@sentry/node"` if you are using ESM
import Sentry from "@sentry/node";
import config from "./config";

if (process.env.NODE_ENV !== "development")
  Sentry.init({
    ...config.sentry,
    // Prevent Sentry from initializing OpenTelemetry to avoid duplicate registration
    // OpenTelemetry is initialized separately in @/config/tracing.config
    skipOpenTelemetrySetup: true,
  });
