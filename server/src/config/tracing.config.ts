import config from "@/config";
import { diag, DiagConsoleLogger, DiagLogLevel } from "@opentelemetry/api";

import { NodeSDK } from "@opentelemetry/sdk-node";
import {
  resourceFromAttributes,
  detectResources,
  envDetector,
  hostDetector,
  osDetector,
} from "@opentelemetry/resources";

import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { OTLPMetricExporter } from "@opentelemetry/exporter-metrics-otlp-http";
import { ExpressInstrumentation } from "@opentelemetry/instrumentation-express";
import { HttpInstrumentation } from "@opentelemetry/instrumentation-http";
import { ATTR_SERVICE_NAME } from "@opentelemetry/semantic-conventions";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";
import { PeriodicExportingMetricReader } from "@opentelemetry/sdk-metrics";

// 🐞 Enable OpenTelemetry debug logging
diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.INFO);

const SKIPPED_URLS = [
  "/health",
  "/metrics",
  "/healthz",
  "/readyz",
  config.serviceability.loki.url,
];

const _detectResources = detectResources({
  detectors: [envDetector, hostDetector, osDetector],
}).merge(
  resourceFromAttributes({
    [ATTR_SERVICE_NAME]: config.infrastructure.serviceName,
    "service.namespace": config.infrastructure.appName,
    "deployment.environment": process.env.NODE_ENV || "development",
  })
);

const getOtelHeaders = () => {
  return { ...config.otel.headers };
};

const isOtelEndpointConfigured = () => {
  const u = config.otel.url?.trim();
  return typeof u === "string" && u.length > 0 && (u.startsWith("http://") || u.startsWith("https://"));
};

// 🧠 SDK setup — only when OTEL endpoint URL is configured (full URL required)
const baseUrl = isOtelEndpointConfigured() ? config.otel.url!.replace(/\/$/, "") : "";
const sdk = new NodeSDK({
  resource: _detectResources,
  ...(isOtelEndpointConfigured() && baseUrl
    ? {
        traceExporter: new OTLPTraceExporter({
          url: `${baseUrl}/v1/traces`,
          headers: getOtelHeaders(),
        }),
        metricReader: new PeriodicExportingMetricReader({
          exporter: new OTLPMetricExporter({
            url: `${baseUrl}/v1/metrics`,
            headers: getOtelHeaders(),
          }),
        }),
      }
    : {}),
  instrumentations: [
    getNodeAutoInstrumentations(),
    new HttpInstrumentation({
      ignoreIncomingRequestHook: (req) => {
        return SKIPPED_URLS.includes(req.url);
      },
    }),
    new ExpressInstrumentation(),
  ],
});

// 🟢 Initialize and start tracing (no-op if OTEL endpoint not configured)
export const initializeTracing = () => {
  try {
    if (!isOtelEndpointConfigured()) {
      return;
    }
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
    if (isOtelEndpointConfigured()) {
      await sdk.shutdown();
      console.log("OpenTelemetry tracing terminated");
    }
  } catch (error) {
    console.error("Error terminating OpenTelemetry:", error);
  }
};

// 🚪 Handle SIGTERM for clean exit in Docker/k8s/etc.
process.on("SIGTERM", () => {
  if (!isOtelEndpointConfigured()) {
    process.exit(0);
    return;
  }
  sdk
    .shutdown()
    .then(() => console.log("OpenTelemetry tracing terminated"))
    .catch((error) => console.error("Error terminating OpenTelemetry", error))
    .finally(() => process.exit(0));
});
