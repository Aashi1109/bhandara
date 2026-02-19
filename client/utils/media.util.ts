export async function generateThumbnailFromVideo(fileOrUrl: string, seekTime = 1) {
  return new Promise((resolve, reject) => {
    const video = document.createElement("video");
    video.crossOrigin = "anonymous";

    // Accept Blob or URL
    video.src = typeof fileOrUrl === "string" ? fileOrUrl : URL.createObjectURL(fileOrUrl);
    video.preload = "metadata";
    video.muted = true;
    video.playsInline = true;

    video.addEventListener("loadedmetadata", () => {
      if (seekTime > video.duration) {
        seekTime = 0; // fallback
      }
      video.currentTime = seekTime;
    });

    video.addEventListener("seeked", () => {
      const canvas = document.createElement("canvas");
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;

      const ctx = canvas.getContext("2d");
      ctx?.drawImage(video, 0, 0, canvas.width, canvas.height);

      // Option 1: get as base64
      const base64Image = canvas.toDataURL("image/jpeg", 0.8);

      // Option 2: get as Blob
      canvas.toBlob((blob) => resolve(blob), "image/jpeg", 0.8);
    });

    video.addEventListener("error", (e) => {
      reject(new Error(`Error loading video: ${  e.message}`));
    });
  });
}
