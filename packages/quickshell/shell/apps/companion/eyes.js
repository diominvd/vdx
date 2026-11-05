.pragma library

// Kimmy's eyes, one look per expression, so the ball draws whatever this says and a
// test can read it. Numbers are fractions of the resting eye:
//   shape        capsule (the two tall black pills) · arc (^ ^, eyes shut with joy) ·
//                spiral (dizzy)
//   w, h         the capsule's width and height; hL / hR one eye only
//   rotL, rotR   the lean of the left and right eye, degrees (+ is clockwise); at rest
//                both lean the same way, as the reference does. Tops leaning in read as
//                cross, tops leaning out as sad.
//   top, bottom  how much of the eye a lid hides from that end (0 … 0.8)
//   lid          the lids' resting squash from both ends (-0.2 wide … 1 shut)
//   dy           the eyes sit lower (+) or higher (-), a fraction of the ball
var rest = { shape: "capsule", w: 1, h: 1, hL: 1, hR: 1, rotL: -24, rotR: -24, top: 0, bottom: 0, lid: 0, dy: 0 };

var looks = {
  idle: {},
  sleeping: { lid: 0.92, rotL: -14, rotR: -14, dy: 0.04 },
  hover: { w: 1.04, h: 1.05, lid: -0.06 },
  curious: { w: 1.05, h: 1.07, rotL: -18, rotR: -18, lid: -0.05 },
  happy: { rotL: 10, rotR: -58, bottom: 0.34 },
  purr: { shape: "arc", dy: 0.02 },
  glee: { shape: "arc", h: 1.12, dy: -0.02 },
  surprised: { w: 1.2, h: 1.14, rotL: -4, rotR: -4, lid: -0.18 },
  panic: { w: 1.28, h: 1.06, rotL: 10, rotR: -14, lid: -0.2 },
  smug: { top: 0.46, rotL: -8, rotR: -8, bottom: 0.06 },
  mischief: { rotL: -4, rotR: -30, top: 0.3 },
  offended: { top: 0.36, rotL: 12, rotR: -56 },
  error: { rotL: 6, rotR: -54, lid: -0.1 },
  sad: { top: 0.24, rotL: -50, rotR: 4, dy: 0.07 },
  sleepy: { top: 0.56, rotL: -12, rotR: -12, dy: 0.03 },
  doze: { top: 0.72, rotL: -8, rotR: -8, dy: 0.04 },
  focus: { top: 0.34, bottom: 0.14, rotL: -32, rotR: -32, w: 1.06 },
  confused: { hR: 0.76, top: 0.08, rotL: -24, rotR: -10 },
  dizzy: { shape: "spiral" },
  proud: { shape: "arc", h: 0.9, dy: -0.04 }
};

function look(mood) {
  const out = {};
  for (const k in rest) out[k] = rest[k];
  const l = looks[mood] || {};
  for (const k in l) out[k] = l[k];
  return out;
}
