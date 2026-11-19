import React from "react";
import {
  AbsoluteFill,
  interpolate,
  OffthreadVideo,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { theme } from "../theme";
import type { ClipScene } from "../storyboard";
import { fontFamily } from "../fonts";
import { easeInOut, easeOut, useUnits } from "../units";

const Screen: React.FC<{ scene: ClipScene }> = ({ scene }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const z = scene.zoom ?? { from: 1, to: 1, origin: "50% 50%" };
  const scale = interpolate(f, [0, Math.round(scene.dur * fps)], [z.from, z.to], {
    easing: easeInOut,
    extrapolateRight: "clamp",
  });
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <div style={{ position: "absolute", inset: 0, transform: `scale(${scale})`, transformOrigin: z.origin }}>
        <OffthreadVideo
          src={staticFile(scene.src)}
          trimBefore={Math.round(scene.trim.from * fps)}
          playbackRate={scene.playbackRate ?? 1}
          muted
          style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }}
        />
        {scene.blur?.map((r, i) => (
          <div
            key={i}
            style={{
              position: "absolute",
              left: `${r.x}%`,
              top: `${r.y}%`,
              width: `${r.w}%`,
              height: `${r.h}%`,
              backdropFilter: "blur(18px)",
              borderRadius: 12,
            }}
          />
        ))}
      </div>
    </div>
  );
};

export const Clip: React.FC<{ scene: ClipScene }> = ({ scene }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { u, vertical, width } = useUnits();

  if (scene.mode === "full") {
    return (
      <AbsoluteFill>
        <Screen scene={scene} />
      </AbsoluteFill>
    );
  }

  const wPct = vertical ? 92 : theme.screen.widthPct;
  const w = (width * wPct) / 100;
  const h = w / (scene.aspect ?? 16 / 9);

  // вход: apple — подъём с затуханием; fluent — наклон по X на пружине
  let enter: React.CSSProperties;
  if (theme.style === "apple") {
    const p = interpolate(f, [0, 30], [0, 1], { easing: easeOut, extrapolateRight: "clamp" });
    enter = { opacity: p, transform: `translateY(${(1 - p) * 40 * u}px)` };
  } else {
    const s = spring({ frame: f, fps, config: { damping: 18, mass: 0.9 } });
    enter = {
      opacity: Math.min(1, s * 1.5),
      transform: `perspective(${2000 * u}px) rotateX(${(1 - s) * 6}deg) scale(${0.96 + 0.04 * s})`,
    };
  }

  const cap = interpolate(f, [8, 32], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", fontFamily }}>
      {scene.caption && (
        <div
          style={{
            position: "absolute",
            top: `calc(50% - ${h / 2 + 96 * u}px)`,
            opacity: cap,
            color: theme.fg,
            fontSize: (vertical ? 56 : 52) * u,
            fontWeight: 600,
            letterSpacing: "-0.02em",
          }}
        >
          {scene.caption}
        </div>
      )}
      <div
        style={{
          ...enter,
          position: "relative",
          width: w,
          height: h,
          borderRadius: theme.screen.radius * u,
          overflow: "hidden",
          boxShadow: theme.screen.shadow,
        }}
      >
        <Screen scene={scene} />
      </div>
    </AbsoluteFill>
  );
};
