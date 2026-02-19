import React, { useRef } from "react";
import type { GestureResponderEvent } from "react-native";

type HoldEnhancerProps = {
  onHold: () => void;
  holdDuration?: number;
  children: React.ReactElement;
};

const Holdable: React.FC<HoldEnhancerProps> = ({ onHold, holdDuration = 600, children }) => {
  const holdTimeout = useRef<NodeJS.Timeout | null>(null);

  const triggerHold = () => {
    holdTimeout.current = setTimeout(() => {
      onHold();
    }, holdDuration);
  };

  const cancelHold = () => {
    if (holdTimeout.current) {
      clearTimeout(holdTimeout.current);
      holdTimeout.current = null;
    }
  };

  const handlePressIn = (event: GestureResponderEvent) => {
    triggerHold();
    children.props.onPressIn?.(event); // Call child’s onPressIn if exists
  };

  const handlePressOut = (event: GestureResponderEvent) => {
    cancelHold();
    children.props.onPressOut?.(event); // Call child’s onPressOut if exists
  };

  return React.cloneElement(children, {
    onPressIn: handlePressIn,
    onPressOut: handlePressOut
  });
};

export default Holdable;
