import React, { useState, useCallback, useRef, useEffect } from "react";
import { Image, View, Text, XStack, YStack } from "tamagui";
import { SpinningLoader } from "@/components/ui/Loaders";
import { ImageOff, Play, Pause } from "@tamagui/lucide-icons";
import Video from "react-native-video";
import { EMediaType } from "@/definitions/enums";
import { useMediaOptimization } from "@/hooks/useMediaOptimization";

interface OptimizedMediaLoaderProps {
  uri: string;
  thumbnailUri?: string;
  type: EMediaType;
  width?: number | string;
  height?: number | string;
  objectFit?: "cover" | "contain" | "fill" | "none" | "scale-down";
  borderRadius?: number | string;
  onLoad?: () => void;
  onError?: (error: any) => void;
  onPress?: () => void;
  showPlayButton?: boolean;
  autoPlay?: boolean;
  muted?: boolean;
  loop?: boolean;
  placeholder?: string;
  fallbackComponent?: React.ReactNode;
  loadingComponent?: React.ReactNode;
  errorComponent?: React.ReactNode;
  style?: any;
  containerStyle?: any;
}

const OptimizedMediaLoader: React.FC<OptimizedMediaLoaderProps> = ({
  uri,
  thumbnailUri,
  type,
  width = "100%",
  height = 280,
  objectFit = "cover",
  borderRadius = 0,
  onLoad,
  onError,
  onPress,
  showPlayButton = false,
  autoPlay = false,
  muted = true,
  loop = true,
  placeholder,
  fallbackComponent,
  loadingComponent,
  errorComponent,
  style,
  containerStyle
}) => {
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);
  const [isVideoPlaying, setIsVideoPlaying] = useState(autoPlay);
  const [imageLoaded, setImageLoaded] = useState(false);
  const videoRef = useRef<Video>(null);
  
  // Use media optimization hook
  const { loadMedia, getMediaStatus } = useMediaOptimization({
    preloadCount: 2,
    enableProgressiveLoading: true
  });

  // Reset states when URI changes
  useEffect(() => {
    setIsLoading(true);
    setHasError(false);
    setImageLoaded(false);
    setIsVideoPlaying(autoPlay);
    
    // Preload media using optimization hook
    if (uri) {
      loadMedia({
        id: uri,
        uri,
        thumbnailUri,
        type
      }).then(() => {
        setIsLoading(false);
        onLoad?.();
      }).catch((error) => {
        setHasError(true);
        onError?.(error);
      });
    }
  }, [uri, autoPlay, loadMedia, thumbnailUri, type, onLoad, onError]);

  const handleLoad = useCallback(() => {
    setIsLoading(false);
    setHasError(false);
    onLoad?.();
  }, [onLoad]);

  const handleError = useCallback((error: any) => {
    setIsLoading(false);
    setHasError(true);
    onError?.(error);
  }, [onError]);

  const handleImageLoad = useCallback(() => {
    setImageLoaded(true);
    handleLoad();
  }, [handleLoad]);

  const handleVideoLoad = useCallback(() => {
    handleLoad();
  }, [handleLoad]);

  const toggleVideoPlayback = useCallback(() => {
    if (isVideoPlaying) {
      videoRef.current?.pause();
      setIsVideoPlaying(false);
    } else {
      videoRef.current?.play();
      setIsVideoPlaying(true);
    }
  }, [isVideoPlaying]);

  const handlePress = useCallback(() => {
    if (type === EMediaType.Video && showPlayButton) {
      toggleVideoPlayback();
    } else {
      onPress?.();
    }
  }, [type, showPlayButton, toggleVideoPlayback, onPress]);

  // Default loading component
  const defaultLoadingComponent = (
    <YStack
      flex={1}
      justifyContent="center"
      alignItems="center"
      backgroundColor="$color5"
      borderRadius={borderRadius}
    >
      <SpinningLoader size="large" />
      <Text fontSize="$2" color="$color10" marginTop="$2">
        Loading...
      </Text>
    </YStack>
  );

  // Default error component
  const defaultErrorComponent = (
    <YStack
      flex={1}
      justifyContent="center"
      alignItems="center"
      backgroundColor="$color5"
      borderRadius={borderRadius}
    >
      <ImageOff size={48} color="$color8" />
      <Text fontSize="$2" color="$color10" marginTop="$2">
        Failed to load media
      </Text>
    </YStack>
  );

  // Default fallback component
  const defaultFallbackComponent = (
    <YStack
      flex={1}
      justifyContent="center"
      alignItems="center"
      backgroundColor="$color5"
      borderRadius={borderRadius}
    >
      <Text fontSize="$2" color="$color10">
        {placeholder || "No media available"}
      </Text>
    </YStack>
  );

  if (hasError) {
    return (
      <View
        width={width}
        height={height}
        style={containerStyle}
        onPress={onPress}
        cursor={onPress ? "pointer" : "default"}
      >
        {errorComponent || defaultErrorComponent}
      </View>
    );
  }

  if (!uri) {
    return (
      <View
        width={width}
        height={height}
        style={containerStyle}
      >
        {fallbackComponent || defaultFallbackComponent}
      </View>
    );
  }

  return (
    <View
      width={width}
      height={height}
      style={containerStyle}
      position="relative"
      onPress={handlePress}
      cursor={onPress || (type === EMediaType.Video && showPlayButton) ? "pointer" : "default"}
    >
      {type === EMediaType.Image ? (
        <>
          {/* Show thumbnail while main image loads */}
          {thumbnailUri && !imageLoaded && (
            <Image
              source={{ uri: thumbnailUri }}
              width={width}
              height={height}
              objectFit={objectFit}
              borderRadius={borderRadius}
              style={style}
            />
          )}
          
          {/* Main image */}
          <Image
            source={{ 
              uri,
              cache: 'force-cache',
              priority: 'high'
            }}
            width={width}
            height={height}
            objectFit={objectFit}
            borderRadius={borderRadius}
            style={[
              style,
              thumbnailUri && !imageLoaded && { opacity: 0 }
            ]}
            onLoad={handleImageLoad}
            onError={handleError}
            placeholder="blur"
            placeholderBlurhash="L6PZ0Si_?.D%%-9IpJM{_j]j@j@"
          />
          
          {/* Loading overlay */}
          {isLoading && (
            <View
              position="absolute"
              top={0}
              left={0}
              right={0}
              bottom={0}
              justifyContent="center"
              alignItems="center"
              backgroundColor="rgba(0,0,0,0.3)"
              borderRadius={borderRadius}
            >
              {loadingComponent || defaultLoadingComponent}
            </View>
          )}
        </>
      ) : type === EMediaType.Video ? (
        <>
          {/* Video thumbnail */}
          {thumbnailUri && (
            <Image
              source={{ uri: thumbnailUri }}
              width={width}
              height={height}
              objectFit={objectFit}
              borderRadius={borderRadius}
              style={style}
            />
          )}
          
          {/* Video component */}
          <Video
            ref={videoRef}
            source={{ 
              uri,
              cache: 'force-cache'
            }}
            style={[
              {
                width,
                height,
                borderRadius: typeof borderRadius === 'number' ? borderRadius : 0
              },
              style
            ]}
            resizeMode={objectFit === 'cover' ? 'cover' : 'contain'}
            paused={!isVideoPlaying}
            muted={muted}
            loop={loop}
            onLoad={handleVideoLoad}
            onError={handleError}
            onEnd={() => setIsVideoPlaying(false)}
            onPlay={() => setIsVideoPlaying(true)}
            onPause={() => setIsVideoPlaying(false)}
          />
          
          {/* Loading overlay */}
          {isLoading && (
            <View
              position="absolute"
              top={0}
              left={0}
              right={0}
              bottom={0}
              justifyContent="center"
              alignItems="center"
              backgroundColor="rgba(0,0,0,0.3)"
              borderRadius={borderRadius}
            >
              {loadingComponent || defaultLoadingComponent}
            </View>
          )}
          
          {/* Play/Pause button overlay */}
          {showPlayButton && (
            <View
              position="absolute"
              top="50%"
              left="50%"
              transform={[{ translateX: -20 }, { translateY: -20 }]}
              backgroundColor="rgba(0,0,0,0.6)"
              borderRadius="$6"
              padding="$2"
              onPress={toggleVideoPlayback}
              cursor="pointer"
            >
              {isVideoPlaying ? (
                <Pause size={24} color="white" />
              ) : (
                <Play size={24} color="white" />
              )}
            </View>
          )}
        </>
      ) : (
        // Fallback for unknown media types
        <View
          width={width}
          height={height}
          style={containerStyle}
        >
          {fallbackComponent || defaultFallbackComponent}
        </View>
      )}
    </View>
  );
};

export default OptimizedMediaLoader;