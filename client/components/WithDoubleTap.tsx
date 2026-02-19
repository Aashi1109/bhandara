import React, { useRef } from "react";
import { type GestureResponderEvent, Pressable } from "react-native";

type DoubleTapProps = {
  onDoubleTap: () => void;
  delay?: number; // Optional: Customize double-tap interval
  children: React.ReactNode;
};

const WithDoubleTap: React.FC<DoubleTapProps> = ({ onDoubleTap, delay = 300, children }) => {
  const lastTap = useRef<number>(0);

  const handlePress = (event: GestureResponderEvent) => {
    const now = Date.now();
    if (lastTap.current && now - lastTap.current < delay) {
      onDoubleTap();
    }
    lastTap.current = now;
  };

  return <Pressable onPress={handlePress}>{children}</Pressable>;
};

export default WithDoubleTap;
