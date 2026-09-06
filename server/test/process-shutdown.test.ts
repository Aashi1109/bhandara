import * as Sentry from '@sentry/node';
import { describe, expect, it, vi } from 'vitest';

const lifecycle = vi.hoisted(() => ({
  initializeTracing: vi.fn(),
  shutdownTracing: vi.fn(),
  stopBoss: vi.fn(),
}));

vi.mock('../src/instrument', () => ({}));
vi.mock('@/common', () => ({
  config: { appName: 'test', appType: 'server' },
  ensureDatabaseSchema: vi.fn(),
  getDBConnection: vi.fn(() => new Promise(() => {})),
  getRedisConnection: vi.fn(),
  initializeTracing: lifecycle.initializeTracing,
  shutdownTracing: lifecycle.shutdownTracing,
}));
vi.mock('@/common/queues/boss', () => ({ stopBoss: lifecycle.stopBoss }));

describe('process shutdown', () => {
  it('flushes once and waits for pg-boss and tracing on SIGTERM or SIGINT', async () => {
    let resolveFlush!: (value: boolean) => void;
    let resolveBoss!: () => void;
    let resolveTracing!: () => void;

    vi.mocked(Sentry.flush).mockReturnValueOnce(new Promise((resolve) => (resolveFlush = resolve)));
    lifecycle.stopBoss.mockReturnValueOnce(new Promise<void>((resolve) => (resolveBoss = () => resolve())));
    lifecycle.shutdownTracing.mockReturnValueOnce(new Promise<void>((resolve) => (resolveTracing = () => resolve())));

    const on = vi.spyOn(process, 'on').mockImplementation((() => process) as typeof process.on);
    const exit = vi.spyOn(process, 'exit').mockImplementation((() => undefined) as never);

    await import('../index');

    const sigterm = on.mock.calls.find(([event]) => event === 'SIGTERM')?.[1] as () => Promise<void>;
    const sigint = on.mock.calls.find(([event]) => event === 'SIGINT')?.[1] as () => Promise<void>;

    expect(sigterm).toBe(sigint);

    const firstShutdown = sigterm();
    const duplicateShutdown = sigint();

    expect(Sentry.flush).toHaveBeenCalledOnce();
    expect(Sentry.flush).toHaveBeenCalledWith(2000);
    expect(lifecycle.stopBoss).not.toHaveBeenCalled();

    resolveFlush(true);
    await vi.waitFor(() => expect(lifecycle.stopBoss).toHaveBeenCalledOnce());

    expect(lifecycle.shutdownTracing).toHaveBeenCalledOnce();
    expect(exit).not.toHaveBeenCalled();

    resolveBoss();
    await Promise.resolve();
    expect(exit).not.toHaveBeenCalled();

    resolveTracing();
    await Promise.all([firstShutdown, duplicateShutdown]);

    expect(exit).toHaveBeenCalledOnce();
    expect(exit).toHaveBeenCalledWith(0);
  });
});
