import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { theme } from "../theme";
import type { TitleScene } from "../storyboard";
import { fontFamily } from "../fonts";
import { easeOut, useUnits } from "../units";

const renderTitle = (title: string, accentWord?: string) => {
  if (!accentWord || !title.includes(accentWord)) return title;
  const [a, ...rest] = title.split(accentWord);
  const accentStyle: React.CSSProperties =
    theme.style === "apple"
      ? { color: theme.accent }
      : {
          backgroundImage: `linear-gradient(90deg, ${theme.accent}, ${theme.accent2})`,
          WebkitBackgroundClip: "text",
          backgroundClip: "text",
          color: "transparent",
        };
  return (
    <>
      {a}
      <span style={accentStyle}>{accentWord}</span>
      {rest.join(accentWord)}
    </>
  );
};

export const Title: React.FC<{ scene: TitleScene }> = ({ scene }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { u, vertical } = useUnits();
  const k = vertical ? 0.62 : 1;

  if (theme.style === "apple") {
    const reveal = (delay: number) => {
      const p = interpolate(f - delay, [0, 24], [0, 1], {
        easing: easeOut,
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      });
      return {
        opacity: p,
        filter: `blur(${(1 - p) * 20 * u}px)`,
        transform: `translateY(${(1 - p) * 24 * u}px)`,
      };
    };
    return (
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", fontFamily, padding: 80 * u }}>
        <div
          style={{
            ...reveal(0),
            color: theme.fg,
            fontSize: 112 * u * k,
            fontWeight: 700,
            letterSpacing: "-0.03em",
            lineHeight: 1.05,
            textAlign: "center",
          }}
        >
          {renderTitle(scene.title, scene.accentWord)}
        </div>
        {scene.subtitle && (
          <div
            style={{
              ...reveal(10),
              color: theme.muted,
              fontSize: 40 * u * k,
              fontWeight: 500,
              marginTop: 28 * u,
              textAlign: "center",
            }}
          >
            {scene.subtitle}
          </div>
        )}
      </AbsoluteFill>
    );
  }

  // fluent: acrylic-карточка на пружине
  const s = spring({ frame: f, fps, config: { damping: 14, mass: 0.8 } });
  const sub = spring({ frame: f - 8, fps, config: { damping: 16 } });
  return (
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", fontFamily }}>
      <div
        style={{
          opacity: s,
          transform: `scale(${0.92 + 0.08 * s})`,
          padding: `${56 * u}px ${88 * u}px`,
          borderRadius: 24 * u,
          background: "rgba(255,255,255,.12)",
          border: `${Math.max(1, u)}px solid rgba(255,255,255,.18)`,
          backdropFilter: "blur(40px) saturate(1.6)",
          boxShadow: `0 ${30 * u}px ${80 * u}px rgba(0,0,0,.25)`,
          textAlign: "center",
          maxWidth: "86%",
        }}
      >
        <div
          style={{
            color: theme.fg,
            fontSize: 96 * u * k,
            fontWeight: 600,
            letterSpacing: "-0.02em",
            lineHeight: 1.08,
          }}
        >
          {renderTitle(scene.title, scene.accentWord)}
        </div>
        {scene.subtitle && (
          <div
            style={{
              opacity: 0.85 * sub,
              color: theme.fg,
              fontSize: 38 * u * k,
              fontWeight: 400,
              marginTop: 20 * u,
            }}
          >
            {scene.subtitle}
          </div>
        )}
      </div>
    </AbsoluteFill>
  );
};
