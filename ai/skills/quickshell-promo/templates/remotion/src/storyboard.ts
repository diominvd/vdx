// Раскадровка: перенести из promo/storyboard.md. Время — в секундах.
// trim.from берётся из .markers (обычно метка "in").

export type Rect = { x: number; y: number; w: number; h: number }; // % от кадра исходника

export type TitleScene = {
  type: "title";
  dur: number;
  title: string;
  subtitle?: string;
  accentWord?: string; // слово в title, окрашенное акцентом
  transition?: "fade" | "cut";
};

export type ClipScene = {
  type: "clip";
  dur: number;
  src: string; // относительно public/, например "clips/02-wifi.mp4"
  trim: { from: number };
  mode: "float" | "full";
  aspect?: number; // соотношение сторон монитора, по умолчанию 16/9 (16:10 → 1.6)
  zoom?: { from: number; to: number; origin: string }; // origin — CSS, "85% 5%"
  caption?: string; // короткая подпись над экраном (только float)
  blur?: Rect[]; // зоны размытия приватных данных
  playbackRate?: number;
  transition?: "fade" | "cut";
};

export type Scene = TitleScene | ClipScene;

export const music: string | null = null; // "music.m4a" в public/

export const scenes: Scene[] = [
  { type: "title", dur: 3, title: "Ваш рабочий стол.", accentWord: "рабочий" },
  {
    type: "clip",
    dur: 6,
    src: "clips/01-reveal.mp4",
    trim: { from: 1.0 },
    mode: "float",
    zoom: { from: 1.0, to: 1.08, origin: "50% 50%" },
  },
  { type: "title", dur: 2, title: "Сеть. Под рукой.", subtitle: "Wi-Fi прямо из панели." },
  {
    type: "clip",
    dur: 7,
    src: "clips/02-wifi.mp4",
    trim: { from: 1.0 },
    mode: "float",
    zoom: { from: 1.0, to: 1.22, origin: "85% 5%" },
    blur: [{ x: 70, y: 8, w: 25, h: 30 }],
  },
  { type: "title", dur: 4, title: "Quickshell", subtitle: "github.com/you/dotfiles", transition: "fade" },
];
