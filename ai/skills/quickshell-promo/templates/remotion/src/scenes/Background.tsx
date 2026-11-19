import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { FPS, theme } from "../theme";

// apple — сплошной фон; fluent — медленно дрейфующий mesh-градиент.
export const Background: React.FC = () => {
  const f = useCurrentFrame();
  if (theme.style === "apple") return <AbsoluteFill style={{ backgroundColor: theme.bg }} />;

  const t = (f / FPS) * ((2 * Math.PI) / 8); // период 8 с
  const p = (phase: number, amp: number) => 50 + Math.sin(t + phase) * amp;
  const blob = (c: string, x: number, y: number) =>
    `radial-gradient(circle at ${x}% ${y}%, ${c} 0%, transparent 55%)`;

  return (
    <AbsoluteFill
      style={{
        backgroundColor: theme.bg,
        backgroundImage: [
          blob(theme.accent, p(0, 30), p(1.3, 20)),
          blob(theme.accent2, p(2.1, 30), p(3.7, 25)),
          blob(theme.accent3, p(4.2, 25), p(0.6, 30)),
        ].join(","),
        filter: "saturate(1.2)",
      }}
    />
  );
};
