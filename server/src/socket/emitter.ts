import type { Namespace } from 'socket.io';

let namespace: Namespace | null = null;

export const setPlatformNamespace = (ns: Namespace) => {
  namespace = ns;
};

export const emitSocketEvent = (
  event: string,
  payload: { data?: any; error?: any },
  options?: { room?: string },
) => {
  if (!namespace) return;

  if (options?.room) {
    namespace.to(options.room).emit(event, payload);
    return;
  }

  namespace.emit(event, payload);
};
