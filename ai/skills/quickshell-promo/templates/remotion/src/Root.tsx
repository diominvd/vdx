import React from "react";
import { Composition } from "remotion";
import { Promo, totalFrames, validate } from "./Promo";
import { FPS } from "./theme";

validate();

export const Root: React.FC = () => {
  const d = totalFrames();
  return (
    <>
      <Composition id="Promo" component={Promo} durationInFrames={d} fps={FPS} width={1920} height={1080} />
      <Composition id="Promo4K" component={Promo} durationInFrames={d} fps={FPS} width={3840} height={2160} />
      <Composition id="PromoVertical" component={Promo} durationInFrames={d} fps={FPS} width={1080} height={1920} />
    </>
  );
};
