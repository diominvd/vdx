import React from "react";
import { AbsoluteFill, Audio, interpolate, staticFile, useVideoConfig } from "remotion";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { FPS, theme } from "./theme";
import { music, scenes, type Scene } from "./storyboard";
import { Background } from "./scenes/Background";
import { Title } from "./scenes/Title";
import { Clip } from "./scenes/Clip";
import "./fonts";

const frames = (s: Scene) => Math.round(s.dur * FPS);
const transFrames = (s: Scene, i: number) =>
  i === 0 || s.transition === "cut" ? 0 : theme.fadeFrames;

export const totalFrames = (): number =>
  scenes.reduce((acc, s, i) => acc + frames(s) - transFrames(s, i), 0);

export const validate = (): void => {
  scenes.forEach((s, i) => {
    const t = Math.max(transFrames(s, i), transFrames(scenes[i + 1] ?? s, i + 1));
    if (frames(s) <= t) throw new Error(`Сцена ${i + 1}: dur короче перехода (${t} кадров)`);
  });
};

export const Promo: React.FC = () => {
  const { durationInFrames } = useVideoConfig();
  return (
    <AbsoluteFill style={{ backgroundColor: theme.bg }}>
      <Background />
      <TransitionSeries>
        {scenes.flatMap((s, i) => {
          const out: React.ReactNode[] = [];
          const t = transFrames(s, i);
          if (t > 0)
            out.push(
              <TransitionSeries.Transition
                key={`t${i}`}
                presentation={fade()}
                timing={linearTiming({ durationInFrames: t })}
              />,
            );
          out.push(
            <TransitionSeries.Sequence key={`s${i}`} durationInFrames={frames(s)}>
              {s.type === "title" ? <Title scene={s} /> : <Clip scene={s} />}
            </TransitionSeries.Sequence>,
          );
          return out;
        })}
      </TransitionSeries>
      {music && (
        <Audio
          src={staticFile(music)}
          volume={(f) =>
            interpolate(f, [0, 30, durationInFrames - 120, durationInFrames], [0, 1, 1, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            })
          }
        />
      )}
    </AbsoluteFill>
  );
};
