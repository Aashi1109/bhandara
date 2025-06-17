import { Namespace } from "socket.io";

let namespace: Namespace | null = null;

export const setPlatformNamespace = (ns: Namespace) => {
  namespace = ns;
};

export const emitSocketEvent = (
  event: string,
  payload: { data?: any; error?: any }
) => {
  if (!namespace) return;
  namespace.emit(event, payload);
};
