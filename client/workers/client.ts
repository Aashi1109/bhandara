let worker: Worker | null = null;
let idCounter = 0;
const pending: Record<number, (value: any)=>void> = {};

export function ensureWorker() {
  if (!worker) {
    worker = new Worker(new URL('./compression.worker.ts', import.meta.url));
    worker.onmessage = (e) => {
      const { id, result, error } = e.data;
      const resolver = pending[id];
      if (resolver) {
        delete pending[id];
        resolver({ result, error });
      }
    };
  }
  return worker;
}

export function runWorker<T>(action: string, payload: any): Promise<T> {
  if (typeof Worker === 'undefined') {
    return Promise.reject(new Error('Worker not supported'));
  }
  ensureWorker();
  return new Promise((resolve, reject) => {
    const id = ++idCounter;
    pending[id] = ({ result, error }) => {
      if (error) reject(new Error(error));
      else resolve(result);
    };
    worker!.postMessage({ id, action, payload });
  });
}
