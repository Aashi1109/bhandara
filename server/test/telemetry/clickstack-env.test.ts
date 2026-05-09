import { afterEach, describe, expect, it, vi } from 'vitest';

const originalEnv = {
  hdxApiKey: process.env.HYPERDX_API_KEY,
  nodeEnv: process.env.NODE_ENV,
  otlpEndpoint: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
};

describe('ClickStack OpenTelemetry environment bootstrapping', () => {
  afterEach(() => {
    vi.resetModules();
    vi.doUnmock('dotenv');

    if (originalEnv.nodeEnv === undefined) {
      delete process.env.NODE_ENV;
    } else {
      process.env.NODE_ENV = originalEnv.nodeEnv;
    }

    if (originalEnv.otlpEndpoint === undefined) {
      delete process.env.OTEL_EXPORTER_OTLP_ENDPOINT;
    } else {
      process.env.OTEL_EXPORTER_OTLP_ENDPOINT = originalEnv.otlpEndpoint;
    }

    if (originalEnv.hdxApiKey === undefined) {
      delete process.env.HYPERDX_API_KEY;
    } else {
      process.env.HYPERDX_API_KEY = originalEnv.hdxApiKey;
    }
  });

  it('loads the ClickStack OTLP endpoint before HyperDX computes metric exporter URLs', async () => {
    vi.resetModules();
    vi.doUnmock('@/src/common/logger');

    process.env.NODE_ENV = 'test';
    delete process.env.OTEL_EXPORTER_OTLP_ENDPOINT;
    delete process.env.HYPERDX_API_KEY;
    const dotenvConfigMock = vi.fn(() => {
      process.env.OTEL_EXPORTER_OTLP_ENDPOINT = 'http://clickstack.test:4318';
      process.env.HYPERDX_API_KEY = 'test-key';
      return { parsed: {}, error: undefined };
    });

    vi.doMock('dotenv', () => ({
      default: { config: dotenvConfigMock },
      config: dotenvConfigMock,
    }));

    await vi.importActual('@/src/common/logger');
    const constants = await import('@hyperdx/node-opentelemetry/build/src/constants');

    expect(dotenvConfigMock).toHaveBeenCalled();
    expect(process.env.OTEL_EXPORTER_OTLP_ENDPOINT).toBe('http://clickstack.test:4318');
    expect(constants.DEFAULT_OTEL_METRICS_EXPORTER_URL).toBe('http://clickstack.test:4318/v1/metrics');
  });
});
