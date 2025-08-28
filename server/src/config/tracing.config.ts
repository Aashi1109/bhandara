import config from "@/config";
import { diag, DiagConsoleLogger, DiagLogLevel } from "@opentelemetry/api";

import { NodeSDK } from "@opentelemetry/sdk-node";
import { resourceFromAttributes } from "@opentelemetry/resources";

import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-proto";
import { ExpressInstrumentation } from "@opentelemetry/instrumentation-express";
import { HttpInstrumentation } from "@opentelemetry/instrumentation-http";
import { ATTR_SERVICE_NAME } from "@opentelemetry/semantic-conventions";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";

// 🐞 Enable OpenTelemetry debug logging
diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.INFO);

const SKIPPED_URLS = [
  "/health",
  "/metrics",
  "/healthz",
  "/readyz",
  config.serviceability.loki.url,
];

const resource = resourceFromAttributes({
  [ATTR_SERVICE_NAME]: config.infrastructure.appName,
});

// 🧠 SDK setup — main telemetry engine
const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: "http://localhost:4318/v1/traces",
  }),
  instrumentations: [
    getNodeAutoInstrumentations(),
    new HttpInstrumentation({
      ignoreIncomingRequestHook: (req) => {
        return SKIPPED_URLS.includes(req.url);
      },
    }),
    new ExpressInstrumentation(),
  ],
  resource,
});

// 🟢 Initialize and start tracing
export const initializeTracing = async (): Promise<void> => {
  try {
    sdk.start();
    console.log("OpenTelemetry tracing initialized");
  } catch (error) {
    console.error("Error initializing OpenTelemetry:", error);
    throw error;
  }
};

// 🔴 Shutdown tracing gracefully (optional on app close)
export const shutdownTracing = async (): Promise<void> => {
  try {
    await sdk.shutdown();
    console.log("OpenTelemetry tracing terminated");
  } catch (error) {
    console.error("Error terminating OpenTelemetry:", error);
  }
};

// 🚪 Handle SIGTERM for clean exit in Docker/k8s/etc.
process.on("SIGTERM", () => {
  sdk
    .shutdown()
    .then(() => console.log("OpenTelemetry tracing terminated"))
    .catch((error) => console.error("Error terminating OpenTelemetry", error))
    .finally(() => process.exit(0));
});
