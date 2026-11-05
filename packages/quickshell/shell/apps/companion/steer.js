.pragma library

// Kimmy's movement and voice, with no QML in it so a test can run them.

// One step of a pet's run: the speed grows with the distance (so it eases in at the
// goal), the velocity follows it with some give (so it leans into turns and overshoots a
// little). p, v, target are {x, y}; dt in seconds. Returns the new {x, y, vx, vy, dist}.
function step(px, py, vx, vy, tx, ty, dt, maxSpeed, arrive, accel) {
  const dx = tx - px, dy = ty - py;
  const dist = Math.hypot(dx, dy);
  let wx = 0, wy = 0;
  if (dist > 0.5) {
    const speed = Math.min(maxSpeed, dist * arrive);
    wx = dx / dist * speed;
    wy = dy / dist * speed;
  }
  const k = Math.min(1, accel * dt);
  const nvx = vx + (wx - vx) * k, nvy = vy + (wy - vy) * k;
  return { x: px + nvx * dt, y: py + nvy * dt, vx: nvx, vy: nvy, dist: dist };
}

function orbit(cx, cy, radius, angle) {
  return { x: cx + Math.cos(angle) * radius, y: cy + Math.sin(angle) * radius * 0.8 };
}

// the point `radius` from (cx, cy) on the side of (fromX, fromY)
function standOff(cx, cy, fromX, fromY, radius) {
  const dx = fromX - cx, dy = fromY - cy;
  const d = Math.hypot(dx, dy);
  if (d < 1) return { x: cx + radius, y: cy };
  return { x: cx + dx / d * radius, y: cy + dy / d * radius };
}

// a sideways swing for a path that is not a ruler line: amplitude fades as it nears
function swing(px, py, tx, ty, t, amp) {
  const dx = tx - px, dy = ty - py, d = Math.hypot(dx, dy);
  if (d < 1) return { x: tx, y: ty };
  const a = amp * Math.sin(t) * Math.min(1, d / 320);
  return { x: tx - dy / d * a, y: ty + dx / d * a };
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

function pick(list, not) {
  if (list.length === 1) return list[0];
  let item;
  do item = list[Math.floor(Math.random() * list.length)]; while (item === not);
  return item;
}

// What it mumbles. Short, silly, never a sentence that asks for a reply. A "|" splits a
// line in two bubbles, the second a beat later.
var phrases = {
  hello: ["я Кимми!", "привет!", "о, это я", "ну здравствуй|я тут живу", "приветик"],
  idle: ["хмм", "ммм…", "пип", "ля-ля-ля", "а что это?", "тук-тук", "бу", "ну-ну", "тю-тю-тю", "ты чем занят?", "что там у тебя?", "я смотрю, смотрю", "угу", "интересненько", "пум-пум"],
  late: ["ты спать собираешься?", "уже поздно…", "а ты не устал?", "ночь же", "все спят|кроме нас"],
  bored: ["скууучно…", "поиграй со мной", "эй. ну эй.", "я тут!", "ску-ука", "эй|ну эй|…ладно, сам приду"],
  out: ["бегу!", "иду-иду", "ага!", "догоню!", "я к тебе!"],
  pester: ["хи-хи", "лови!", "пристаю~", "ну поиграй", "мой курсор!", "кусь", "бдыщ!", "а-а-а, попался"],
  home: ["я дома", "фух", "на место", "сижу"],
  happy: ["мур", "ура!", "ещё!", "ыыы", "мур-мур"],
  surprised: ["о?", "ой!", "ай!", "ого"],
  dizzy: ["ууу…", "всё кружится", "где верх?", "я вижу три курсора", "ой-ой-ой|земля, стой"],
  yawn: ["хааам", "спатки…", "устал…"],
  zzz: ["з-з-з", "зззз…", "хр-р", "з…", "мрр… з-з"],
  wake: ["а? я не сплю", "о, ты тут", "ммм?"],
  woken: ["ну вот, разбудил", "что? кто?", "я спал вообще-то", "м-м-м… зачем"],
  back: ["домой…", "я устал", "пойду посплю", "ну, я пошёл"],
  sulk: ["ну и ладно…", "я обиделся", "пойду один", "ты занят, да?", "ладно-ладно"],
  huff: ["хм!", "не разговариваю", "я обижен", "…", "хмпф"],
  forgive: ["ладно, мир", "ну ладно…", "прощаю|в этот раз", "мир?"],
  shy: ["ой, быстро!", "не так резко!", "ай!", "уф, напугал"],
  glad: ["ты вернулся!", "а-а, ты тут!", "ага, заметил!"],
  grabbed: ["ой-ой", "куда?!", "я лечу?", "эй, поставь", "уи-и", "держи крепче"],
  grabbedAsleep: ["а?! что?!", "я сплю вообще-то!", "ааа, кто тут", "пожар?!"],
  caughtMe: ["поймал меня!", "ой, на лету!", "хоп!"],
  carryFun: ["уи-и-и", "выше!", "я птица", "вжу-у-ух", "катай меня"],
  panic: ["а-а-а!", "не тряси!", "мама", "стоп-стоп-стоп", "укачало…"],
  thrown: ["аааа", "лечу-у!", "уииии", "за что-о-о", "вжу-у-ух"],
  bonk: ["бум!", "ай, стена", "бдыщ", "ой!"],
  again: ["ещё! ещё!", "давай ещё раз!", "это было круто|ещё?", "ещё кидай!", "ещё разок!"],
  grump: ["ну вот зачем", "я не мячик|ну, мячик, но всё равно", "больно вообще-то", "хмпф", "не кидайся"],
  dropped: ["оп", "плюх", "я тут посижу", "приземлился"],
  doze: ["я тут посплю…", "тепло…", "мрр…", "не шевелись"],
  handOk: ["уютно", "ладно, держи", "ты тёплый", "мм, ладошка"],
  squirm: ["пусти!", "ну пусти-и", "я сам!", "щекотно!"],
  slip: ["вывернулся!", "ха, не поймаешь", "свобода!"],
  purr: ["мрррр", "вот тут, да", "ещё чуть-чуть", "мур-р", "м-м-м", "приятно…", "левее|да, вот так"],
  melt: ["сейчас усну…", "я растаял", "не останавливайся"],
  clingy: ["не уходи", "а ты куда?", "погладь ещё", "эй, а я?"],
  pokePlay: ["хи!", "щекотно!", "а ну ещё", "ты чего?|а, играем!", "бип!", "пип!"],
  pokeMad: ["эй!", "не тычь", "ну хватит", "я тебе не кнопка", "хмф", "больно же"],
  meh: ["м?", "ну ткнул и ткнул", "лень…", "отстань, я отдыхаю", "угу, угу"],
  trick: ["та-да!", "видал?", "оп-ля!", "ещё так могу", "хоп!"],
  refuse: ["не-а", "сам прыгай", "я устал", "потом", "не сегодня"],
  ready: ["сейчас…", "тсс", "ага…"],
  caught: ["поймал!", "мой!", "попался!", "хап!"],
  missed: ["эх", "ушёл…", "почти!", "в следующий раз"],
  stalk: ["тсс…", "крадусь", "меня не видно"],
  boo: ["бу!", "бу-у!", "испугался?", "бу!|хи-хи"],
  hide: ["меня тут нет", "я спрятался", "ищи!"],
  peekaboo: ["ку-ку!", "нашёл!", "ой, нашёл", "ку-ку"],
  beg: ["ещё!", "ну кинь", "давай ещё", "я готов!"],
  played: ["наигрался…", "уф, всё, отдыхаю", "хорошо поиграли", "всё|я мячик без сил"],
  newWindow: ["о, новенькое", "что там?", "ого, окно", "кто пришёл?", "а это кто?"],
  closeWindow: ["пока!", "пока-пока", "ушло…", "бай"],
  workspace: ["вжух", "куда всё делось?", "о, переезд", "всё поменялось"],
  fullscreen: ["ого, на весь экран", "ничего не видно!", "кино?", "тсс, смотрим"],
  windowed: ["вернулось", "фух, опять видно", "ну вот"],
  urgent: ["тебя зовут!", "эй, там что-то!", "срочно!", "смотри, смотри"],
  reload: ["всё обновилось", "ой, перезагрузка", "новенькое!"],
  monitorNew: ["ого, новый экран!", "тут стало больше места"],
  monitorGone: ["куда он делся?", "экран пропал…"],
  musicOn: ["о, музычка!", "ммм, играет", "под это можно танцевать", "включили!"],
  musicOff: ["тишина…", "стихло", "а где музыка?"],
  track: ["новая песня!", "о, это знакомое", "ля-ля-ля", "мне нравится"],
  cpuHot: ["жарко!", "ух, процессор пыхтит", "тяжело тянем…", "ой-ой, нагрузка"],
  cpuCool: ["фух, отпустило", "полегче", "можно дышать"],
  plugIn: ["ам! вкусно", "заряжаемся!", "ура, питание", "ням"],
  plugOut: ["эй, а еда?", "от розетки отключили", "теперь на своих"],
  hungry: ["я голодный…", "заряд на нуле", "покорми меня"],
  full: ["сыт!", "полный бак", "наелся"],
  knock: ["тук-тук, тебе пришло", "тебе написали", "дзынь!", "кто-то стучится"],
  muted: ["ш-ш-ш", "тихо-тихо", "звук выключили"],
  unmuted: ["опять слышно", "звук вернулся"],
  late: ["уже поздно…", "пора бы спать", "ночь на дворе"],
  veryLate: ["два часа ночи!", "ты вообще спишь?", "ложись уже"],
  morning: ["доброе утро!", "с добрым утром", "утро!"],
  hello: ["привет!", "я тут", "а вот и ты"],
  meet: ["привет! я Кимми", "ой, ты настоящий?", "здравствуй, я тут живу", "давай дружить?"],
  missedLong: ["ты вернулся! я скучал", "наконец-то!", "я уже думал, ты не придёшь", "где ты был так долго?"],
  back: ["вот и ты", "о, давно не виделись", "с возвращением"],
  offHour: ["ты сегодня не как обычно", "что-то ты не вовремя", "странное время для тебя"],
  pause: ["ты давно сидишь, разомнись", "может, перерыв?", "глазкам бы отдохнуть", "давай чай?"],
  longSit: ["мы так долго сидим…", "ты уже совсем засиделся", "встань, потянись, я подожду"],
  app_terminal: ["опять хакерим?", "чёрный экран, я люблю", "ого, команды!", "только не rm -rf"],
  app_editor: ["пишем код?", "строчки, строчки…", "я верю в тебя", "баг будет повержен"],
  app_browser: ["ушли в интернеты", "что там нового?", "только не засиживайся"],
  app_chat: ["поболтаем?", "кто там пишет?", "передавай привет"],
  app_game: ["ура, играем!", "я болею за тебя", "погнали!"],
  app_video: ["кино? тихо-тихо", "я тоже посмотрю", "ммм, кино"],
  app_notes: ["записываем мысли?", "умные мысли пошли", "пиши, пиши"],
  dream: ["мм… печеньки…", "бегу… бегу…", "ммф… пип…", "ещё минуточку…", "зырк… зырк…"],
  wakeDream: ["мне снилось, что я большой", "ух, снился сон", "что-то снилось… забыл", "мне снилось, что мы летали"],
  explore: ["а что тут у нас?", "дай-ка гляну", "интересненько", "так-так-так…", "что это тут?", "обход!"],
  dayPlayful: ["сегодня я игривый!", "хочу играть", "настроение — огонь"],
  dayLazy: ["что-то я сегодня ленивый…", "ммм, не хочу двигаться", "сегодня в режиме лени"],
  dayCheery: ["я сегодня в хорошем настроении", "так хорошо!", "улыбаюсь весь день"],
  dayGrumpy: ["я сегодня не в духе", "не трогай, ворчу", "встал не с той стороны"],
  dayClingy: ["побудь со мной сегодня", "мне сегодня хочется рядом", "не уходи далеко"],
  dayCurious: ["сегодня всё интересно!", "хочу всё посмотреть", "а это что? а это?"],
  stageKnow: ["кажется, я тебя уже знаю", "мы уже не чужие"],
  stageFriend: ["мы теперь друзья!", "я считаю тебя другом", "ты мой друг, да?"],
  stageBest: ["ты мой лучший друг", "я тебе совсем доверяю", "с тобой мне ничего не страшно"],
  fav_terminal: ["ты столько времени в терминале", "опять чёрный экран, любимый"],
  fav_editor: ["ты же вечно что-то пишешь", "код — твоя стихия"],
  fav_browser: ["ты любишь побродить по сети", "интернеты — твой дом"],
  fav_chat: ["ты много болтаешь, я заметил", "общительный ты"],
  fav_game: ["ты любишь поиграть, я знаю", "когда играем?"],
  fav_video: ["ты любишь кино, да?", "опять посмотрим что-нибудь?"],
  fav_notes: ["ты столько всего записываешь", "умный ты, всё в заметки"],
  tagInvite: ["поймай меня!", "давай в догонялки!", "а ну догони!", "играем? лови!"],
  tagCaught: ["поймал!", "ах, поймал!", "ты быстрый!", "ладно, ладно, твоя взяла"],
  tagWon: ["не поймал! ха-ха", "я быстрее!", "ура, я выиграл", "ещё разок?"],
  grumble: ["бу-бу-бу", "хм", "ворчу", "ну-ну"],
  love: ["ты хороший", "мне с тобой нравится", "мур", "я рядом"],
  tired: ["зеваю…", "что-то я сонный", "ммм… устал"],
  bop: ["ту-дум", "ритм!", "ля-ля"]
};

// how often a kind is left unsaid (a reply is half as often): a pet is not a radio
var quiet = {
  idle: 0.35, pester: 0.3, purr: 0.45, zzz: 0.4, ready: 0.5, stalk: 0.5, hide: 0.4, beg: 0.4,
  grabbed: 0.35, carryFun: 0.4, dropped: 0.5, bonk: 0.3, newWindow: 0.3, closeWindow: 0.35,
  fullscreen: 0.2, windowed: 0.3, urgent: 0.1, reload: 0.3, monitorNew: 0, monitorGone: 0, workspace: 0.3, home: 0.4, handOk: 0.4, love: 0.3, grumble: 0.3, tired: 0.3, trick: 0.25,
  caught: 0.2, missed: 0.3, back: 0.3, glad: 0.2, shy: 0.25
};


// Where it leaves one screen for another. cur and other are {x, y, w, h} in layout pixels;
// y0 is the layout y it is at now. Returns the exit on cur's edge (a little past it, to
// stand on the very edge), the entry just inside other, and the side it leaves by.
function edgeExit(cur, other, y0, x0, r) {
  const ccx = cur.x + cur.w / 2, ccy = cur.y + cur.h / 2;
  const ocx = other.x + other.w / 2, ocy = other.y + other.h / 2;
  const horizontal = Math.abs(ocx - ccx) / (cur.w + other.w) >= Math.abs(ocy - ccy) / (cur.h + other.h);
  if (horizontal) {
    const right = ocx > ccx;
    const lo = Math.max(cur.y, other.y) + r, hi = Math.min(cur.y + cur.h, other.y + other.h) - r;
    const y = hi > lo ? clamp(y0, lo, hi) : clamp(y0, cur.y + r, cur.y + cur.h - r);
    return { side: right ? "right" : "left", ex: right ? cur.x + cur.w : cur.x, ey: y,
             nx: right ? other.x + r * 1.5 : other.x + other.w - r * 1.5, ny: clamp(y, other.y + r, other.y + other.h - r) };
  }
  const below = ocy > ccy;
  const lo = Math.max(cur.x, other.x) + r, hi = Math.min(cur.x + cur.w, other.x + other.w) - r;
  const x = hi > lo ? clamp(x0, lo, hi) : clamp(x0, cur.x + r, cur.x + cur.w - r);
  return { side: below ? "bottom" : "top", ex: x, ey: below ? cur.y + cur.h : cur.y,
           nx: clamp(x, other.x + r, other.x + other.w - r), ny: below ? other.y + r * 1.5 : other.y + other.h - r * 1.5 };
}

// the screen a layout point is on, or null
function screenAt(screens, x, y) {
  for (const s of screens) if (x >= s.x && y >= s.y && x < s.x + s.w && y < s.y + s.h) return s;
  return null;
}

// How far a slow hand coaxes it: 0 (not at all) … 1. Near, slow, and coming closer: it
// leans toward the hand. A fast hand is a flick (the brain shies), a still one is nothing.
function coax(d, speed, closing, r) {
  if (d > r * 3.2 || speed < 8 || speed > 140 || closing <= 0) return 0;
  return clamp(1 - d / (r * 3.2), 0, 1) * clamp(closing, 0, 1);
}

// The walls of a screen in its own coordinates (the ball's centre may go that far), opened
// where another screen lies behind them. cur / others are {x, y, w, h} in layout pixels;
// (lx, ly) is the ball in cur's coordinates; r its radius.
function reachBounds(cur, others, lx, ly, r) {
  const gx = lx + cur.x, gy = ly + cur.y;
  let x0 = cur.x, x1 = cur.x + cur.w, y0 = cur.y, y1 = cur.y + cur.h;
  for (const s of others) {
    if (gy >= s.y && gy < s.y + s.h) {
      if (s.x <= x1 + 1 && s.x + s.w > x1) x1 = s.x + s.w;
      if (s.x + s.w >= x0 - 1 && s.x < x0) x0 = s.x;
    }
    if (gx >= s.x && gx < s.x + s.w) {
      if (s.y <= y1 + 1 && s.y + s.h > y1) y1 = s.y + s.h;
      if (s.y + s.h >= y0 - 1 && s.y < y0) y0 = s.y;
    }
  }
  return { x0: x0 - cur.x + r, x1: x1 - cur.x - r, y0: y0 - cur.y + r, y1: y1 - cur.y - r };
}

// ---- the model's line ----
// What the free model is told: who it is, what to answer, and the moment's facts.
function witPrompt(facts) {
  return "Ты — Кимми, маленький шарик-питомец, живёшь на рабочем столе у хозяина и дружишь с ним. "
    + "Скажи ОДНУ короткую реплику вслух про текущий момент: не больше 8 слов, по-русски, тепло и чуть игриво, "
    + "без кавычек, без эмодзи, без пояснений, не повторяй факты дословно. Момент: " + facts;
}

// A model's answer made safe to show in a bubble: the first line, no quotes or a name
// prefix, Russian and short; "" when it is none of that.
function cleanLine(raw) {
  let t = String(raw || "").split("\n").map(l => l.trim()).filter(l => l !== "")[0] ?? "";
  const edge = /^[\s"«“'`*_]+|[\s"»”'`*_]+$/g;
  t = t.replace(edge, "").replace(/^(кимми|kimmy)\s*[:\-—]\s*/i, "").replace(edge, "");
  if (t === "" || !/[а-яё]/i.test(t) || /https?:|www\.|```/.test(t)) return "";
  if (t.length > 80) {
    const cut = t.slice(0, 80);
    t = cut.slice(0, Math.max(20, cut.lastIndexOf(" "))).replace(/[,;:\s]+$/, "") + "…";
  }
  return t;
}
