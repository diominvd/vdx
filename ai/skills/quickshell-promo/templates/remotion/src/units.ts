import { Easing, useVideoConfig } from "remotion";

// 1u = 1px на 1080p; все размеры в сценах — в u.
export const useUnits = () => {
  const { width, height } = useVideoConfig();
  const vertical = height > width;
  const u = Math.min(width, height) / 1080;
  return { u, vertical, width, height };
};

export const easeInOut = Easing.bezier(0.45, 0, 0.2, 1);
export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
