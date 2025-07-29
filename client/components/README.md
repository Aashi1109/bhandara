# Explore Asset Preview Components

This directory contains components for implementing Instagram-like full-size preview functionality for the explore section, with optimized media loading for the best UX experience.

## Components

### ExploreAssetPreview

A comprehensive component that provides full-size preview functionality for explore assets, similar to Instagram's post preview.

**Features:**
- Full-size modal preview with zoom capabilities
- Progressive media loading with thumbnails
- Hover effects and smooth animations
- Distance calculation and location display
- Creator information and tags
- Like, comment, and engagement metrics
- Customizable preview button text

**Props:**
```typescript
interface ExploreAssetPreviewProps {
  media: {
    type: string;
    url: string;
    thumbnailUrl: string;
  };
  title: string;
  location: any;
  creator: IBaseUser;
  createdAt: string;
  startTime?: string;
  endTime?: string;
  likes?: number;
  comments?: number;
  going?: number;
  userLocation?: LocationObjectCoords | null;
  tags?: any[];
  onPress?: () => void;
  showPreviewButton?: boolean;
  previewButtonText?: string;
}
```

**Usage:**
```tsx
<ExploreAssetPreview
  media={item.media}
  title={item.title}
  location={item.location}
  creator={item.creator}
  createdAt={item.createdAt}
  likes={item.likes}
  comments={item.comments}
  userLocation={userLocation}
  tags={item.tags}
  showPreviewButton={true}
  previewButtonText="Watch"
/>
```

### OptimizedMediaLoader

A high-performance media loader component that provides progressive loading, caching, and fallback handling.

**Features:**
- Progressive loading with thumbnails
- Automatic caching and memory management
- Error handling with fallback components
- Video playback controls
- Loading states and animations
- Cross-platform compatibility

**Props:**
```typescript
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
```

**Usage:**
```tsx
<OptimizedMediaLoader
  uri={media.url}
  thumbnailUri={media.thumbnailUrl}
  type={media.type}
  width="100%"
  height={280}
  objectFit="cover"
  showPlayButton={media.type === EMediaType.Video}
  onPress={handlePreviewPress}
/>
```

## Hooks

### useMediaOptimization

A custom hook for managing media caching, preloading, and optimization.

**Features:**
- Intelligent media preloading
- Cache management with timeout
- Progressive loading support
- Queue management for concurrent loads
- Cache statistics and monitoring

**Options:**
```typescript
interface UseMediaOptimizationOptions {
  preloadCount?: number;        // Number of items to preload (default: 3)
  cacheTimeout?: number;        // Cache timeout in ms (default: 5 minutes)
  enableProgressiveLoading?: boolean; // Enable thumbnail preloading (default: true)
}
```

**Usage:**
```tsx
const { preloadMedia, loadMedia, getMediaStatus, clearCache } = useMediaOptimization({
  preloadCount: 3,
  cacheTimeout: 5 * 60 * 1000,
  enableProgressiveLoading: true
});

// Preload multiple media items
await preloadMedia([
  { id: '1', uri: 'image1.jpg', thumbnailUri: 'thumb1.jpg', type: EMediaType.Image },
  { id: '2', uri: 'video1.mp4', thumbnailUri: 'thumb2.jpg', type: EMediaType.Video }
]);

// Load a single media item
const mediaUri = await loadMedia({
  id: '1',
  uri: 'image1.jpg',
  type: EMediaType.Image
});

// Check media status
const status = getMediaStatus('1'); // 'not-loaded' | 'loading' | 'loaded' | 'error'
```

## Integration with Explore Sections

The components are integrated into all explore sections:

### Reels Section
- Uses `ExploreAssetPreview` with "Watch" button
- Optimized for video content
- Shows engagement metrics

### Collaborations Section
- Uses `ExploreAssetPreview` with "View Event" button
- Displays event details and creator info
- Shows attendee count

### Trending Section
- Uses `ExploreAssetPreview` with "Trending" button
- Highlights popular events
- Shows verification status

### FoodieFeed Section
- Uses `ExploreAssetPreview` with "Live" button
- Real-time event updates
- Distance-based sorting

### TasteCalendar Section
- Uses `ExploreAssetPreview` with "View" button
- Time-based filtering
- Event scheduling information

## Performance Optimizations

### Media Loading
- **Progressive Loading**: Thumbnails load first, then full media
- **Caching**: Intelligent cache management with timeout
- **Preloading**: Anticipatory loading of nearby content
- **Queue Management**: Prevents concurrent loading conflicts

### UX Enhancements
- **Smooth Animations**: Hover effects and transitions
- **Loading States**: Clear feedback during media loading
- **Error Handling**: Graceful fallbacks for failed loads
- **Responsive Design**: Adapts to different screen sizes

### Memory Management
- **Cache Cleanup**: Automatic removal of expired cache entries
- **Memory Monitoring**: Tracks cache usage and performance
- **Optimized Rendering**: Efficient re-renders and updates

## Best Practices

1. **Always provide thumbnails** for better progressive loading
2. **Use appropriate media types** (Image vs Video)
3. **Handle loading states** to provide user feedback
4. **Implement error boundaries** for graceful failure handling
5. **Monitor cache performance** and adjust settings as needed
6. **Test on different devices** to ensure consistent performance

## Future Enhancements

- [ ] Lazy loading for large media collections
- [ ] Advanced caching strategies (LRU, etc.)
- [ ] Media compression and optimization
- [ ] Offline support and sync
- [ ] Analytics and performance monitoring
- [ ] Accessibility improvements
- [ ] Internationalization support