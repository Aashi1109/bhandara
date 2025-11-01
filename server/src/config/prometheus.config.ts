import config from "@/config";
import client from "prom-client";

// Create a registry
const register = new client.Registry();

// Configure remote write to Grafana Cloud Prometheus
const remoteWriteConfig = {
  url: config.grafanaCloud.prometheusRemoteWriteUrl,
  auth: {
    username: config.grafanaCloud.prometheusUsername,
    password: config.grafanaCloud.prometheusPassword,
  },
  headers: {
    "Content-Type": "application/x-protobuf",
    "Content-Encoding": "snappy",
  },
};

// Default system metrics
client.collectDefaultMetrics({
  register,
  prefix: config.infrastructure.appName + "_",
});

// Custom metrics
const httpRequestCounter = new client.Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status"], // Add labels for method, route, and status
});
register.registerMetric(httpRequestCounter);

const responseTimeHistogram = new client.Histogram({
  name: "http_response_time_seconds",
  help: "HTTP response time in seconds",
  labelNames: ["method", "route", "status"],
  buckets: [0.1, 0.5, 1, 2, 5], // Response time buckets
});
register.registerMetric(responseTimeHistogram);

// Remote write function to send metrics to Grafana Cloud
const sendMetricsToGrafanaCloud = async () => {
  try {
    const metrics = await register.metrics();

    // Convert metrics to Prometheus format and send via HTTP POST
    const response = await fetch(remoteWriteConfig.url, {
      method: "POST",
      headers: {
        ...remoteWriteConfig.headers,
        Authorization: `Basic ${Buffer.from(
          `${remoteWriteConfig.auth.username}:${remoteWriteConfig.auth.password}`
        ).toString("base64")}`,
      },
      body: metrics,
    });

    if (!response.ok) {
      console.error(
        `Failed to send metrics to Grafana Cloud: ${response.status} ${response.statusText}`
      );
    }
  } catch (error) {
    console.error("Error sending metrics to Grafana Cloud:", error);
  }
};

// Send metrics every 15 seconds
// setInterval(sendMetricsToGrafanaCloud, 15000);

export {
  register,
  httpRequestCounter,
  responseTimeHistogram,
  // sendMetricsToGrafanaCloud,
};
