# Companion

A lively ball with eyes beside the bar (`apps/companion/`). No model, no chat, no
service behind it: it exists to look alive. Shell Manager › Kimmy (`apps/shellmanager/KimmyPage.qml`):
a live preview, then the rows of `CompanionSettings.qml` (Body, Eyes, Halo, Home, Behaviour,
Voice; the search index reads them through the page). The look is fully customisable, part by
part, no presets (`CompanionStyle.qml` resolves the keys; unset = the white ball with black eyes).

- `CompanionWindow.qml` — one click-through window on the first screen with a bar,
  in the bar's row; only the ball takes the pointer. `qs ipc call companion poke`
  clicks it. Started by hand it runs alone: `qs -p <dir with shell.qml>`.
- `CompanionBall.qml` — the character. Gaze is a spring after a target (pointer, random
  saccade); blinks are irregular and of three kinds; every reaction has a priority, a
  hold time and a cooldown, so none cuts a stronger one or repeats at once. Fidgets
  every 4-13 s (ten kinds: hop, wiggle, look round, stretch, double take, yawn, ...); clicks: one hops, two or
  three startle, a fourth makes it dizzy; a pointer left over it pets it; it dozes off
  after five quiet minutes. Reduced motion (`Motion.bar`): no breath, saccades, fidgets
  or springs; blinks stay.

Since the touch rework the brain (`CompanionBrain.qml`) decides and the ball plays:
- `mind.js` — pure: four slow moods (energy, affection, curiosity, grumpy) that drift
  back to the temper's values over minutes and pick every reply; touch physics (release
  velocity, throw flight with walls and bounces, stroke detection, carry agitation);
  act weights; log-normal timing. `eyes.js` — one eye look per expression (capsules cut
  by lids, ^ ^ arcs, dizzy spirals).
- Touch: press squashes it; click = poke (reply by moods and recent pokes); double click
  = trick (flip / spin / bounce, refused when tired); hold = dozes, settles or squirms out;
  drag = carried (hangs, swings, panics when shaken); fast release = thrown. Strokes over
  it (back and forth) make it purr; a resting pointer gets a slow blink.
- Play at the pointer: orbit, follow, dash, pounce when it stops, stalk + "boo", hide
  behind an edge and peek, beg after a fun throw. Memory per session: played (tired),
  petted (clingy), ignored (sulks longer).
- World: `Hyprland.rawEvent` (window open/close/move/focus, workspace, fullscreen, urgent,
  configreloaded, monitors), no polling; window centres from `lastIpcObject` after a `refreshToplevels` at most every 4 s.
- Your work: `noticeApp` knows the kind of the focused program (terminal, editor, browser, chat, game, video, notes) by its class and has a word about it, once per kind per 25 min. Asleep it dreams aloud and tells the dream on waking. The shared memory between days is `CompanionMemory.qml` (`~/.local/state/vdx/kimmy.json`: bond, last seen, days; warmer baseline, greetings, a break reminder).
- Exploring (`explore`, `nextVisit`, `inspect`): now and then, curious and rested, it walks to the open windows of its screen (`Hyprland.toplevels`, active workspace), stands on a title edge or peers over a side, looks in and has a word by the program's kind. Not on a clock; `qs -p <dir> ipc call companion explore` starts it by hand. A close pointer ends it (it comes to play).
- Character: a mood of the day (six, rolled every ~6 h, kept in the memory file; a grumpy one is rarer the closer you are), bond stages (strangers, acquaintances, friends, best friends; each crossing is announced once, a friend comes to sit by you, a best friend does not startle), habits (which kinds of programs you spend time in; it remarks on the favourite). Tag: "catch me!" (`invite`, `qs -p <dir> ipc call companion tag`): it runs from the pointer for ~20-30 s; touch it to win.
- The machine (`CompanionPulse.qml`): values the shell already holds, no polling of its own:
  music (sways while it plays, reacts to a new track), CPU >= 85 % for 9 s (sweats), the
  charger (plug / unplug / low / full), a new notification (a knock), mute, the hour
  (SystemClock, hourly) and a greeting at start. At home it also has its own life
  (`homeLife`): watches the pointer, mutters, yawns, wiggles.
- The window also goes full-screen while the pointer is on the ball at home, so a press
  can turn into a drag; the mask is the lifted ball (`hit`).

Not detectable: clicks elsewhere and typing (no global input in Quickshell; only the
polled pointer and Hyprland events).
Test: `tests/test_companion.py`.

Monitors: one window, on the screen it is on. It hops to another monitor on its own (it
runs to the shared edge, looks across, gathers, and the window is remade on the other
screen), to follow a pointer that went there or to explore. The window also moves house
after the focus has stayed on another monitor for six seconds (`CompanionHost.qml`).

Over an edge: a carried or thrown ball goes on into the next monitor (`reach` opens the
walls where a screen lies behind them); a click-through `companion-ghost` window on each
screen it reaches draws a twin of it, and the real window moves to the screen it lands on
(`rehome`). The window uses `exclusionMode: Ignore`, or the bar's strip shifts it down.
