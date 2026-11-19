// Палитра и стиль. Заполняется из inventory.md (раздел «Палитра»).

export type StyleName = "apple" | "fluent";

export const theme = {
  style: "apple" as StyleName,

  // Палитра оболочки
  bg: "#000000",
  fg: "#f5f5f7",
  muted: "#86868b",
  accent: "#7aa2f7",
  accent2: "#bb9af7",
  accent3: "#2ac3de", // только для fluent-градиента

  // Экран в режиме float
  screen: {
    widthPct: 82, // % ширины кадра (вертикальный формат — 92)
    radius: 18,
    shadow: "0 40px 120px rgba(0,0,0,.55)",
  },

  // Переход между сценами по умолчанию, кадры при 60 fps
  fadeFrames: 15,
};

export const FPS = 60;
