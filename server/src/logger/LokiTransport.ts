import axios from 'axios';
import TransportStream, { type TransportStreamOptions } from 'winston-transport';

interface LokiTransportOptions extends TransportStreamOptions {
  lokiUrl?: string;
  labels?: Record<string, string>;
  flushInterval?: number;
  maxBatchSize?: number;
}

type LogEntry = [string, string]; // [timestamp (ns), message]

export class LokiTransport extends TransportStream {
  private lokiUrl: string;
  private labels: Record<string, string>;
  private flushInterval: number;
  private maxBatchSize: number;
  private logBuffer: LogEntry[] = [];

  constructor(opts: LokiTransportOptions = {}) {
    super(opts);

    this.lokiUrl = opts.lokiUrl ?? '';
    this.labels = opts.labels ?? {};
    this.flushInterval = opts.flushInterval ?? 1000;
    this.maxBatchSize = opts.maxBatchSize ?? 100;

    setInterval(() => this.flush(), this.flushInterval).unref();
  }

  log(info: any, callback: () => void) {
    setImmediate(() => this.emit('logged', info));

    const timestamp = `${Date.now()}000000`; // ms to ns
    const message = `[${info.level === 'http' ? 'info' : info.level}] ${info.message}`;

    this.logBuffer.push([timestamp, message]);

    if (this.logBuffer.length >= this.maxBatchSize) {
      this.flush();
    }

    callback();
  }

  private async flush() {
    if (this.logBuffer.length === 0) return;

    const batch = this.logBuffer.splice(0, this.maxBatchSize);

    const payload = {
      streams: [
        {
          stream: this.labels,
          values: batch,
        },
      ],
    };

    try {
      await axios.post(this.lokiUrl, payload, {
        headers: { 'Content-Type': 'application/json' },
      });
    } catch (err: any) {
      console.error('Loki transport push failed:', err.message);
    }
  }
}
