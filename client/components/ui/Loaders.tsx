import { Spinner , View } from "tamagui";
import React from "react";
import { useTheme } from "@tamagui/core";

export const SpinningLoader = ({
  size = "small",
  color = "$accent11"
}: {
  size?: "small" | "large";
  color?: string;
}) => {
  return (
    <Spinner
      size={size}
      color={color}
    />
  );
};

type CircularProgressLoaderProps = {
  progress: number;
  size?: number;
  color?: any;
  trackColor?: any;
  children?: React.ReactNode;
};

export const CircularProgressLoader = ({
  progress,
  size = 40,
  color = "$accent11",
  trackColor = "$color4",
  children
}: CircularProgressLoaderProps) => {
  const theme = useTheme();

  const radius = size / 2;
  const strokeWidth = 4;
  const adjustedRadius = radius - strokeWidth / 2;
  const circumference = 2 * Math.PI * adjustedRadius;
  const strokeDashoffset = circumference - (progress / 100) * circumference;

  if (progress < 0 || progress > 100) return null;

  const resolvedColor = theme[color]?.get();
  const resolvedTrackColor = theme[trackColor]?.get();

  return (
    <View
      width={size}
      height={size}
      position="relative"
      items="center"
      justify="center"
    >
      <svg
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
      >
        <circle
          cx={radius}
          cy={radius}
          r={adjustedRadius}
          fill="none"
          stroke={resolvedTrackColor}
          strokeWidth={strokeWidth}
        />
        <circle
          cx={radius}
          cy={radius}
          r={adjustedRadius}
          fill="none"
          stroke={resolvedColor}
          strokeWidth={strokeWidth}
          strokeDasharray={circumference}
          strokeDashoffset={strokeDashoffset}
          transform={`rotate(-90 ${radius} ${radius})`}
          strokeLinecap="round"
          style={{ transition: "stroke-dashoffset 0.3s ease" }}
        />
      </svg>

      {children && (
        <View
          position="absolute"
          items="center"
          justify="center"
          width={size}
          height={size}
          pointerEvents="none"
        >
          {children}
        </View>
      )}
    </View>
  );
};
