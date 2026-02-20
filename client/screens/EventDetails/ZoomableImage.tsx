import React, { useRef, useEffect, useState } from "react";
import {
  Animated,
  Platform,
  PanResponder,
  type NativeSyntheticEvent,
  type NativeTouchEvent,
  type PanResponderGestureState,
  type View as RNView
} from "react-native";
import { type ImageProps, type ViewProps, View, Image } from "tamagui";

interface ZoomableImageProps {
  uri: string;
  scale: number;
  imageStyle?: ImageProps;
  containerStyle?: ViewProps;
  minScale?: number;
  maxScale?: number;
}

export const ZoomableImage: React.FC<ZoomableImageProps> = ({
  uri,
  scale,
  imageStyle,
  containerStyle,
  minScale = 1,
  maxScale = 3
}) => {
  const scaleAnim = useRef(new Animated.Value(scale)).current;
  const translate = useRef(new Animated.ValueXY({ x: 0, y: 0 })).current;
  const lastOffset = useRef({ x: 0, y: 0 });
  const containerRef = useRef<RNView>(null);
  const [layout, setLayout] = useState({ width: 0, height: 0, x: 0, y: 0 });

  // Update zoom level from parent
  useEffect(() => {
    Animated.spring(scaleAnim, {
      toValue: Math.min(Math.max(scale, minScale), maxScale),
      useNativeDriver: true
    }).start();
  }, [scale]);

  // Get container size and max allowed translation so image edges never leave container
  const getMaxOffsets = (currentScale: number = scale) => {
    if (!layout.width || !layout.height) return { x: 0, y: 0 };

    // Calculate the scaled dimensions
    const scaledWidth = layout.width * currentScale;
    const scaledHeight = layout.height * currentScale;

    // Calculate how much the scaled image extends beyond the container
    const overflowX = Math.max(0, scaledWidth - layout.width) / 2;
    const overflowY = Math.max(0, scaledHeight - layout.height) / 2;

    return { x: overflowX, y: overflowY };
  };

  // Clamp translation values to bounds
  const clampTranslation = (x: number, y: number, currentScale: number = scale) => {
    const { x: maxX, y: maxY } = getMaxOffsets(currentScale);

    return {
      x: maxX === 0 ? 0 : Math.max(-maxX, Math.min(x, maxX)),
      y: maxY === 0 ? 0 : Math.max(-maxY, Math.min(y, maxY))
    };
  };

  // Clamp translation when scale or layout changes
  useEffect(() => {
    if (!layout.width || !layout.height) return;

    translate.stopAnimation((currentValue) => {
      const val = currentValue as { x: number; y: number };
      const clamped = clampTranslation(val.x, val.y);

      translate.setValue(clamped);
      lastOffset.current = clamped;
    });
  }, [scale, layout.width, layout.height]);

  // --- 🖱 Web: Mouse-based panning with clamping
  useEffect(() => {
    if (Platform.OS !== "web") return;
    const el = (containerRef.current as any)?._node || containerRef.current;
    if (!el || scale <= 1) return;

    let isDragging = false;
    let startPos = { x: 0, y: 0 };
    let initialOffset = { x: 0, y: 0 };

    const onMouseDown = (e: MouseEvent) => {
      isDragging = true;
      startPos = { x: e.clientX, y: e.clientY };
      initialOffset = { ...lastOffset.current };
      e.preventDefault();
    };

    const onMouseMove = (e: MouseEvent) => {
      if (!isDragging) return;

      const dx = e.clientX - startPos.x;
      const dy = e.clientY - startPos.y;

      const nextX = initialOffset.x + dx;
      const nextY = initialOffset.y + dy;

      const clamped = clampTranslation(nextX, nextY);

      translate.setValue(clamped);
    };

    const onMouseUp = () => {
      if (!isDragging) return;
      isDragging = false;

      translate.stopAnimation((value) => {
        const v = value as { x: number; y: number };
        const clamped = clampTranslation(v.x, v.y);
        lastOffset.current = clamped;
        translate.setValue(clamped);
      });
    };

    el.addEventListener("mousedown", onMouseDown);
    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("mouseup", onMouseUp);

    return () => {
      el.removeEventListener("mousedown", onMouseDown);
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("mouseup", onMouseUp);
    };
  }, [scale, layout]);

  // --- 🤏 Native panResponder with clamping
  const panResponder =
    Platform.OS !== "web"
      ? PanResponder.create({
          onStartShouldSetPanResponder: () => scale > 1,
          onMoveShouldSetPanResponder: () => scale > 1,
          onPanResponderGrant: () => {
            // Don't use setOffset, work with absolute values
          },
          onPanResponderMove: (
            evt: NativeSyntheticEvent<{ touches: NativeTouchEvent[] }>,
            gestureState: PanResponderGestureState
          ) => {
            const touches = evt.nativeEvent.touches;
            if (touches.length === 1 && scale > 1) {
              const nextX = lastOffset.current.x + gestureState.dx;
              const nextY = lastOffset.current.y + gestureState.dy;

              const clamped = clampTranslation(nextX, nextY);
              translate.setValue(clamped);
            }
          },
          onPanResponderRelease: () => {
            translate.stopAnimation((v) => {
              const val = v as { x: number; y: number };
              const clamped = clampTranslation(val.x, val.y);
              lastOffset.current = clamped;
              translate.setValue(clamped);
            });
          }
        })
      : undefined;

  return (
    <View
      ref={containerRef}
      overflow="hidden"
      onLayout={(e) => {
        const { width, height, x, y } = e.nativeEvent.layout;
        setLayout({ width, height, x, y });
      }}
      {...containerStyle}
    >
      {layout.width > 0 && (
        <Animated.View
          {...(Platform.OS !== "web" ? panResponder?.panHandlers : {})}
          style={{
            width: layout.width,
            height: layout.height,
            transform: [{ scale: scaleAnim }, { translateX: translate.x }, { translateY: translate.y }]
          }}
        >
          <Image
            src={uri}
            width={layout.width}
            height={layout.height}
            objectFit="contain"
            {...imageStyle}
          />
        </Animated.View>
      )}
    </View>
  );
};
