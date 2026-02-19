import { useEffect, useRef } from "react";
import { type Socket, io } from "socket.io-client";
import config from "@/config";

export type EventHandler = (...args: any[]) => void;

const usePlatformSocket = (handlers: Record<string, EventHandler> = {}) => {
  const socketRef = useRef<Socket>();

  useEffect(() => {
    const socket = io(`${config.server.url}/platform`);
    socketRef.current = socket;

    Object.entries(handlers).forEach(([event, handler]) => {
      socket.on(event, handler);
    });

    return () => {
      Object.entries(handlers).forEach(([event, handler]) => {
        socket.off(event, handler);
      });
      socket.disconnect();
    };
  }, []);

  return socketRef;
};

export default usePlatformSocket;
