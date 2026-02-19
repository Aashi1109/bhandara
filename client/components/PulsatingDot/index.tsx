import React, { useEffect, useRef } from "react";
import { Animated, StyleSheet , Easing } from "react-native";
import { View } from "tamagui";

const PulsatingDot = ({ size = 16, color = "$accent1", pulseScale = 2.5, duration = 1200 }) => {
  const scaleAnim = useRef(new Animated.Value(1)).current;
  const opacityAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    const loop = Animated.loop(
      Animated.parallel([
        Animated.timing(scaleAnim, {
          toValue: pulseScale,
          duration,
          easing: Easing.out(Easing.ease),
          useNativeDriver: true
        }),
        Animated.timing(opacityAnim, {
          toValue: 0,
          duration,
          easing: Easing.out(Easing.ease),
          useNativeDriver: true
        })
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [scaleAnim, opacityAnim, duration, pulseScale]);

  return (
    <View
      items={"center"}
      justify={"center"}
    >
      <View
        bg={color as any}
        width={0}
        height={0}
        visibility="hidden"
        position="relative"
      >
        <Animated.View
          style={[
            styles.pulse,
            {
              width: size,
              height: size,
              borderRadius: size / 2,
              backgroundColor: "inherit",
              opacity: opacityAnim,
              top: 0,
              left: -size / 2,
              transform: [{ scale: scaleAnim }]
            }
          ]}
        />
      </View>
      <View
        width={size}
        height={size}
        rounded={size / 2}
        bg={color as any}
        z={1}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  pulse: {
    position: "absolute"
  }
});

export default PulsatingDot;
