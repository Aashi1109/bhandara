import { useState, useEffect, useCallback, useRef } from 'react';
import { EMediaType } from '@/definitions/enums';

interface MediaItem {
  id: string;
  uri: string;
  thumbnailUri?: string;
  type: EMediaType;
  priority?: 'high' | 'medium' | 'low';
}

interface UseMediaOptimizationOptions {
  preloadCount?: number;
  cacheTimeout?: number;
  enableProgressiveLoading?: boolean;
}

interface MediaCache {
  [key: string]: {
    data: any;
    timestamp: number;
    loading: boolean;
    error: boolean;
  };
}

export const useMediaOptimization = (options: UseMediaOptimizationOptions = {}) => {
  const {
    preloadCount = 3,
    cacheTimeout = 5 * 60 * 1000, // 5 minutes
    enableProgressiveLoading = true
  } = options;

  const [mediaCache, setMediaCache] = useState<MediaCache>({});
  const [preloadedMedia, setPreloadedMedia] = useState<Set<string>>(new Set());
  const loadingQueue = useRef<Set<string>>(new Set());
  const cacheTimeoutRef = useRef<NodeJS.Timeout>();

  // Clean up expired cache entries
  const cleanupCache = useCallback(() => {
    const now = Date.now();
    setMediaCache(prev => {
      const newCache = { ...prev };
      Object.keys(newCache).forEach(key => {
        if (now - newCache[key].timestamp > cacheTimeout) {
          delete newCache[key];
        }
      });
      return newCache;
    });
  }, [cacheTimeout]);

  // Set up periodic cache cleanup
  useEffect(() => {
    if (cacheTimeoutRef.current) {
      clearInterval(cacheTimeoutRef.current);
    }
    
    cacheTimeoutRef.current = setInterval(cleanupCache, cacheTimeout);
    
    return () => {
      if (cacheTimeoutRef.current) {
        clearInterval(cacheTimeoutRef.current);
      }
    };
  }, [cleanupCache, cacheTimeout]);

  // Preload media items
  const preloadMedia = useCallback(async (mediaItems: MediaItem[]) => {
    const itemsToPreload = mediaItems
      .filter(item => !preloadedMedia.has(item.id) && !loadingQueue.current.has(item.id))
      .slice(0, preloadCount);

    if (itemsToPreload.length === 0) return;

    // Mark items as loading
    itemsToPreload.forEach(item => loadingQueue.current.add(item.id));

    try {
      // Preload thumbnails first for progressive loading
      if (enableProgressiveLoading) {
        await Promise.allSettled(
          itemsToPreload
            .filter(item => item.thumbnailUri)
            .map(async (item) => {
              try {
                await preloadImage(item.thumbnailUri!);
                setMediaCache(prev => ({
                  ...prev,
                  [`${item.id}-thumbnail`]: {
                    data: item.thumbnailUri,
                    timestamp: Date.now(),
                    loading: false,
                    error: false
                  }
                }));
              } catch (error) {
                console.warn(`Failed to preload thumbnail for ${item.id}:`, error);
              }
            })
        );
      }

      // Then preload full media
      await Promise.allSettled(
        itemsToPreload.map(async (item) => {
          try {
            if (item.type === EMediaType.Image) {
              await preloadImage(item.uri);
            } else if (item.type === EMediaType.Video) {
              await preloadVideo(item.uri);
            }

            setMediaCache(prev => ({
              ...prev,
              [item.id]: {
                data: item.uri,
                timestamp: Date.now(),
                loading: false,
                error: false
              }
            }));

            setPreloadedMedia(prev => new Set([...prev, item.id]));
          } catch (error) {
            console.warn(`Failed to preload media for ${item.id}:`, error);
            setMediaCache(prev => ({
              ...prev,
              [item.id]: {
                data: null,
                timestamp: Date.now(),
                loading: false,
                error: true
              }
            }));
          } finally {
            loadingQueue.current.delete(item.id);
          }
        })
      );
    } catch (error) {
      console.error('Error preloading media:', error);
      itemsToPreload.forEach(item => loadingQueue.current.delete(item.id));
    }
  }, [preloadCount, preloadedMedia, enableProgressiveLoading]);

  // Preload a single image
  const preloadImage = (uri: string): Promise<void> => {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve();
      img.onerror = () => reject(new Error(`Failed to load image: ${uri}`));
      img.src = uri;
    });
  };

  // Preload a single video
  const preloadVideo = (uri: string): Promise<void> => {
    return new Promise((resolve, reject) => {
      const video = document.createElement('video');
      video.preload = 'metadata';
      video.onloadedmetadata = () => resolve();
      video.onerror = () => reject(new Error(`Failed to load video: ${uri}`));
      video.src = uri;
    });
  };

  // Load a single media item
  const loadMedia = useCallback(async (mediaItem: MediaItem): Promise<string> => {
    const cacheKey = mediaItem.id;
    
    // Check if already cached
    if (mediaCache[cacheKey] && !mediaCache[cacheKey].loading && !mediaCache[cacheKey].error) {
      return mediaCache[cacheKey].data;
    }

    // Check if already loading
    if (loadingQueue.current.has(cacheKey)) {
      // Wait for loading to complete
      return new Promise((resolve, reject) => {
        const checkCache = () => {
          if (mediaCache[cacheKey] && !mediaCache[cacheKey].loading) {
            if (mediaCache[cacheKey].error) {
              reject(new Error(`Failed to load media: ${cacheKey}`));
            } else {
              resolve(mediaCache[cacheKey].data);
            }
          } else {
            setTimeout(checkCache, 100);
          }
        };
        checkCache();
      });
    }

    // Mark as loading
    loadingQueue.current.add(cacheKey);
    setMediaCache(prev => ({
      ...prev,
      [cacheKey]: {
        data: null,
        timestamp: Date.now(),
        loading: true,
        error: false
      }
    }));

    try {
      let data: string;
      
      if (mediaItem.type === EMediaType.Image) {
        await preloadImage(mediaItem.uri);
        data = mediaItem.uri;
      } else if (mediaItem.type === EMediaType.Video) {
        await preloadVideo(mediaItem.uri);
        data = mediaItem.uri;
      } else {
        throw new Error(`Unsupported media type: ${mediaItem.type}`);
      }

      setMediaCache(prev => ({
        ...prev,
        [cacheKey]: {
          data,
          timestamp: Date.now(),
          loading: false,
          error: false
        }
      }));

      return data;
    } catch (error) {
      setMediaCache(prev => ({
        ...prev,
        [cacheKey]: {
          data: null,
          timestamp: Date.now(),
          loading: false,
          error: true
        }
      }));
      throw error;
    } finally {
      loadingQueue.current.delete(cacheKey);
    }
  }, [mediaCache]);

  // Get media status
  const getMediaStatus = useCallback((mediaId: string) => {
    const cached = mediaCache[mediaId];
    if (!cached) return 'not-loaded';
    if (cached.loading) return 'loading';
    if (cached.error) return 'error';
    return 'loaded';
  }, [mediaCache]);

  // Clear cache
  const clearCache = useCallback(() => {
    setMediaCache({});
    setPreloadedMedia(new Set());
    loadingQueue.current.clear();
  }, []);

  // Get cache statistics
  const getCacheStats = useCallback(() => {
    const total = Object.keys(mediaCache).length;
    const loading = Object.values(mediaCache).filter(item => item.loading).length;
    const error = Object.values(mediaCache).filter(item => item.error).length;
    const loaded = total - loading - error;
    
    return {
      total,
      loading,
      error,
      loaded,
      preloaded: preloadedMedia.size
    };
  }, [mediaCache, preloadedMedia]);

  return {
    preloadMedia,
    loadMedia,
    getMediaStatus,
    clearCache,
    getCacheStats,
    mediaCache,
    preloadedMedia: Array.from(preloadedMedia)
  };
};