.pragma library

// Kimmy's temperament and the physics of touching it, with no QML in it so a test can
// run every decision. A decision takes its dice (r, 0..1) as an argument: the brain
// rolls Math.random(), a test rolls what it wants.

// ---- moods ----
// Four slow moods colour everything; each drifts back to the temper's own resting value
// over minutes and is pushed by what happens.
//   energy     stamina: play drains it, rest and sleep restore it
//   affection  how much it likes you right now: stroking, play; ignoring it lowers it
//   curiosity  how much the world interests it: windows, the pointer, new things
//   grumpy     pokes, hard throws, being ignored; stroking melts it
function baseFor(temper) {
  if (temper === "calm") return { energy: 0.45, affection: 0.5, curiosity: 0.35, grumpy: 0.15 };
  if (temper === "clingy") return { energy: 0.6, affection: 0.75, curiosity: 0.5, grumpy: 0.12 };
  return { energy: 0.62, affection: 0.5, curiosity: 0.6, grumpy: 0.18 };
}

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

// relax every mood toward its base: tau seconds is the time constant
function drift(m, base, dt, tau) {
  const k = 1 - Math.exp(-dt / tau);
  for (const key in base) m[key] = m[key] + (base[key] - m[key]) * k;
  return m;
}

// what a moment does to the moods (scaled by `amount`, 1 by default)
var effects = {
  stroke:  { affection: 0.035, grumpy: -0.05, energy: -0.004 },
  poke:    { grumpy: 0.07, curiosity: 0.02 },
  pokeFun: { affection: 0.02, energy: -0.01 },
  trick:   { energy: -0.05, affection: 0.02 },
  carry:   { curiosity: 0.03 },
  throwFun:{ energy: -0.07, affection: 0.04, grumpy: -0.02 },
  throwBad:{ energy: -0.05, grumpy: 0.14, affection: -0.04 },
  shaken:  { grumpy: 0.1, energy: -0.04 },
  play:    { energy: -0.035, affection: 0.03 },
  ignored: { affection: -0.08, grumpy: 0.1 },
  sleep:   { energy: 0.35, grumpy: -0.1 },
  world:   { curiosity: 0.03 }
};
function nudge(m, kind, amount) {
  const e = effects[kind];
  if (!e) return m;
  const a = amount === undefined ? 1 : amount;
  for (const key in e) m[key] = clamp01(m[key] + e[key] * a);
  return m;
}

// a count that fades: half-life `half` seconds
function fade(v, dt, half) { return v * Math.pow(0.5, dt / half); }

// ---- timing ----
// not a fixed beat: a log-normal around `mean`, `spread` 0.2 is a little, 0.6 a lot
function jitter(mean, spread, r1, r2) {
  const a = Math.max(1e-6, r1 === undefined ? Math.random() : r1);
  const b = r2 === undefined ? Math.random() : r2;
  const g = Math.sqrt(-2 * Math.log(a)) * Math.cos(2 * Math.PI * b);
  return mean * Math.exp(spread * Math.max(-2.5, Math.min(2.5, g)));
}

// a weighted pick that never repeats anything in `recent`
function pickWeighted(weights, recent, r) {
  const roll = r === undefined ? Math.random() : r;
  const keys = Object.keys(weights).filter(k => weights[k] > 0 && (recent || []).indexOf(k) < 0);
  const pool = keys.length ? keys : Object.keys(weights).filter(k => weights[k] > 0);
  let total = 0;
  for (const k of pool) total += weights[k];
  let at = roll * total;
  for (const k of pool) { at -= weights[k]; if (at <= 0) return k; }
  return pool[pool.length - 1];
}

// a phrase not said lately; "" now and then when it would rather stay quiet
function pickFresh(list, recent, r) {
  const fresh = list.filter(p => (recent || []).indexOf(p) < 0);
  const pool = fresh.length ? fresh : list;
  return pool[Math.floor((r === undefined ? Math.random() : r) * pool.length) % pool.length];
}

// ---- decisions ----
// a click on it: a jolt first, then this, by mood and by how many came lately
function pokeReply(m, recentPokes, r) {
  if (recentPokes >= 5) return m.energy > 0.4 ? "dizzy" : "offended";
  const cross = m.grumpy + 0.13 * (recentPokes - 1) - m.affection * 0.35;
  if (r < cross) return "offended";
  if (m.energy < 0.25) return "meh";
  return "playful";
}

// thrown, landed: impact 0 a toss … 1 bounced off every wall
function throwReply(m, impact, r) {
  if (impact > 0.72 && r < 0.4 + impact * 0.3) return "dizzy";
  const delight = 0.25 + m.energy * 0.55 + m.affection * 0.35 - m.grumpy * 0.6 - Math.max(0, impact - 0.6) * 0.5;
  return r < delight ? "delighted" : "grumpy";
}
function impact(speed, walls, turns) {
  return clamp01(speed / 2600 + walls * 0.18 + turns * 0.08);
}

// held still in the hand for `heldS` seconds
function holdReply(m, asleep, r) {
  if (asleep) return "doze";
  if (m.energy < 0.4 && m.affection > 0.4) return "doze";
  if (m.grumpy > 0.45 || (m.energy > 0.7 && r < 0.6)) return "squirm";
  return r < 0.25 + m.grumpy ? "squirm" : "content";
}

// a double click: a trick, never the same twice in a row; a tired one will not
function trickKind(m, last, r) {
  if (m.energy < 0.2 && r < 0.75) return "refuse";
  const w = { flip: 3, spin: 2, bounce: 2 };
  if (m.energy > 0.7) w.flip += 2;
  return pickWeighted(w, [last], r);
}

// after a landing: stay and play, go home, or have a rest right here
function afterLand(m, played, r) {
  if (played > 3.5 || m.energy < 0.18) return "rest";
  if (m.grumpy > 0.6) return "home";
  return r < 0.3 + m.energy * 0.4 + m.affection * 0.3 ? "play" : "home";
}

// what to do next at the pointer: weights from the moods and the pointer's own life
// (moving: how fast it goes, still: seconds it has kept still)
function actWeights(m, moving, still, begging) {
  const w = {
    orbit: 1.2 + m.energy,
    follow: moving > 60 ? 2.2 : 0.4,
    dash: 0.6 + m.energy * 1.2,
    peek: 1 + (1 - m.energy),
    hop: 0.8 + m.affection,
    pounce: still > 0.3 && still < 3 ? 2.4 + m.energy * 2 : 0,
    stalk: moving > 40 && moving < 700 ? 0.8 + m.curiosity * 2.2 : 0,
    hide: 0.5 + m.curiosity * 0.8 + m.grumpy * 0.6,
    beg: begging ? 4 : 0
  };
  return w;
}

// ---- touch ----
// release velocity from the last pointer samples [{x, y, t ms}]: the run over the last
// `windowMs`; 0 if the pointer had already stopped `stopMs` before the release
function velocity(samples, now, windowMs, stopMs) {
  if (!samples || samples.length < 2) return { vx: 0, vy: 0 };
  const last = samples[samples.length - 1];
  if (now - last.t > stopMs) return { vx: 0, vy: 0 };
  let first = last;
  for (let i = samples.length - 1; i >= 0; i--) { if (last.t - samples[i].t > windowMs) break; first = samples[i]; }
  if (first === last) first = samples[samples.length - 2];
  const dt = Math.max(8, last.t - first.t) / 1000;
  return { vx: (last.x - first.x) / dt, vy: (last.y - first.y) / dt };
}

// one stroke detector per axis: a stroke is a run one way of at least minTravel px
// ended by a turn. Returns the run's direction (-1 / 1) when one ends, else 0.
function stroke(st, v, t, minTravel) {
  if (st.at === undefined || t - st.t > 600) { st.at = v; st.dir = 0; st.travel = 0; st.t = t; return 0; }
  const d = v - st.at;
  st.at = v;
  st.t = t;
  if (Math.abs(d) < 0.5) return 0;
  const dir = d > 0 ? 1 : -1;
  let beat = 0;
  if (dir !== st.dir) {
    if (st.dir !== 0 && st.travel >= minTravel) beat = st.dir;
    st.travel = 0;
    st.dir = dir;
  }
  st.travel += Math.abs(d);
  return beat;
}

// how rough a carry is: the change of velocity, fading in half a second
function agitate(a, dvx, dvy, dt) { return fade(a, dt, 0.45) + Math.hypot(dvx, dvy) / 9000; }

// one step of a throw. s {x, y, vx, vy, z, vz} changes in place; b {x0, x1, y0, y1}
// the walls. Air barely slows it, the ground rubs; walls and the ground give back part
// of the speed. Returns what it hit this step: {wall, side, ground} (speeds, px/s).
var flyK = { g: 2600, air: 0.35, ground: 4.2, bounce: 0.42, wall: 0.62 };
function fly(s, dt, b, k) {
  const c = k || flyK;
  const ev = { wall: 0, side: "", ground: 0 };
  s.vz -= c.g * dt;
  s.z += s.vz * dt;
  if (s.z <= 0) {
    s.z = 0;
    if (s.vz < -110) { ev.ground = -s.vz; s.vz = -s.vz * c.bounce; }
    else s.vz = 0;
  }
  const f = Math.exp(-(s.z > 0 ? c.air : c.ground) * dt);
  s.vx *= f;
  s.vy *= f;
  s.x += s.vx * dt;
  s.y += s.vy * dt;
  if (s.x < b.x0 && s.vx < 0) { s.x = b.x0; ev.wall = -s.vx; ev.side = "x"; s.vx = -s.vx * c.wall; }
  else if (s.x > b.x1 && s.vx > 0) { s.x = b.x1; ev.wall = s.vx; ev.side = "x"; s.vx = -s.vx * c.wall; }
  if (s.y < b.y0 && s.vy < 0) { s.y = b.y0; ev.wall = Math.max(ev.wall, -s.vy); ev.side = "y"; s.vy = -s.vy * c.wall; }
  else if (s.y > b.y1 && s.vy > 0) { s.y = b.y1; ev.wall = Math.max(ev.wall, s.vy); ev.side = "y"; s.vy = -s.vy * c.wall; }
  s.done = s.z === 0 && s.vz === 0 && Math.hypot(s.vx, s.vy) < 22;
  return ev;
}

// the nearest screen edge to hide behind (not the top: the bar is there), and the
// point past it where only a sliver of the ball shows
function hideSpot(x, y, w, h, r) {
  const left = x, right = w - x, bottom = h - y;
  if (bottom < left && bottom < right) return { x: x, y: h + r * 0.45, side: "bottom" };
  return left < right ? { x: -r * 0.45, y: y, side: "left" } : { x: w + r * 0.45, y: y, side: "right" };
}
