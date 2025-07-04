self.onmessage = async (e) => {
  const { id, action, payload } = e.data;
  try {
    let result;
    switch (action) {
      case 'compressImage': {
        const { uri, width, percentage } = payload;
        const { default: imageCompression } = await import('browser-image-compression');
        const blob = await fetch(uri).then(r => r.blob());
        const maxSizeMB = (blob.size / 1024 / 1024) * ((percentage ?? 100) / 100);
        const compressed = await imageCompression(blob, {
          maxSizeMB,
          maxWidthOrHeight: width || 1280,
          useWebWorker: true,
        });
        result = {
          uri: URL.createObjectURL(compressed),
          blob: compressed,
          size: compressed.size,
        };
        break;
      }
      case 'imageVariants': {
        const { uri, mimeType } = payload;
        const { default: imageCompression } = await import('browser-image-compression');
        const blob = await fetch(uri).then(r => r.blob());
        const compress = async (width:number) => {
          const compressed = await imageCompression(blob, {
            maxWidthOrHeight: width,
            useWebWorker: true,
          });
          return { uri: URL.createObjectURL(compressed), blob: compressed, size: compressed.size };
        };
        const low = await compress(400);
        const high = await compress(800);
        result = [
          { ...low, suffix: '@1x' },
          { ...high, suffix: '@2x' }
        ];
        break;
      }
      default:
        result = null;
    }
    self.postMessage({ id, result });
  } catch (error: any) {
    self.postMessage({ id, error: error.message });
  }
};
