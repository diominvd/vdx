---
name: quickshell-promo
description: Делает промо-ролик Quickshell-оболочки (Arch + Hyprland) в стиле Apple или Windows/Fluent — инвентаризация конфига, раскадровка, скриптованные дубли через hyprctl и qs ipc, запись, монтаж в Remotion, рендер и экспорт. Use when the user asks for a promo video, trailer, showcase or presentation video of their Quickshell shell, rice or desktop.
---

# Quickshell Promo

Пайплайн: **конфиг → раскадровка → скриптованные дубли → запись → монтаж в Remotion → рендер → проверка**.

## Правила

1. **Каждый кадр — воспроизводимый скрипт.** Никакой ручной записи экрана. Дубль = `promo/takes/NN-slug.sh`, перезаписывается одной командой.
2. **Только реальные фичи.** В раскадровку попадает лишь то, что найдено в конфиге (`inventory.md`) и подтверждено пользователем. Не придумывать возможности и цифры в подписях.
3. **Конфиг пользователя не трогать.** Окружение меняется только в рантайме (`hyprctl keyword`, `qs ipc`), откат — `scripts/restore-env.sh` (`hyprctl reload`). Если для демо нужны моки данных — отдельная ветка git, с согласия пользователя.
4. **Приватность.** SSID соседей, уведомления, треки, hostname, username, пути — либо демо-данные, либо размытие в монтаже. Проверять каждый contact sheet.
5. **Одна идея на сцену.** Подпись ≤ 4 слов, подзаголовок ≤ 10 слов, только факт.

## Пути

Скрипты скилла: `${CLAUDE_SKILL_DIR}` (если переменной нет — каталог этого файла, обычно `~/.claude/skills/quickshell-promo`). Рабочая папка проекта ролика — `./promo/` в текущей директории:

```
promo/
  inventory.md      # шаг 1
  storyboard.md     # шаг 2
  takes/NN-slug.sh  # шаг 3
  raw/NN-slug.mp4 + .markers + .png (contact sheet)   # шаг 4
  video/            # Remotion-проект (из templates/remotion), клипы в video/public/clips/
  out/              # рендеры
```

## Шаги

### 0. Зависимости
`bash $SKILL/scripts/check-deps.sh`. Обязательны: `hyprctl qs ffmpeg ffprobe jq node npx` и один рекордер (`gpu-screen-recorder` предпочтительнее — CFR; иначе `wf-recorder`). Опционально: `ydotool` (клики, нужен `ydotoold`), `wtype` (ввод текста). Недостающее — сообщить пользователю с командой установки, самому не ставить.

### 1. Инвентаризация
`bash $SKILL/scripts/inspect-shell.sh [config_dir] > promo/inventory.md`
(именованный конфиг: `QS_CONFIG=name`). Затем прочитать ключевые QML-файлы и документацию в конфиге (например `PLUGIN_STYLE.md`, README). Дописать в `inventory.md`:
- список модулей/плагинов и что каждый умеет визуально;
- как каждый открывается: IPC-таргет (`qs ipc call <target> <fn>`), GlobalShortcut (`hyprctl dispatch global <appid>:<name>`), клик, бинд Hyprland;
- палитра оболочки (основные цвета, акцент) — уйдёт в `theme.ts`;
- что показывает приватные данные.

Если у нужного виджета нет IPC/шортката — предложить пользователю добавить `IpcHandler` (в его стиле кода) либо снимать через `glide` + `click`.

### 2. Раскадровка — СТОП-точка
Прочитать `reference/storyboard.md` и `reference/style.md`. Записать `promo/storyboard.md` по шаблону оттуда. **Показать пользователю и ждать подтверждения**: стиль (`apple` | `fluent`), язык подписей, длительность, список сцен, формат (16:9 / 4K / 9:16), музыка (файл даёт пользователь — скилл музыку не ищет и не скачивает).

### 3. Дубли
Для каждой сцены с клипом — `promo/takes/NN-slug.sh` по шаблону `templates/take.sh`. API в `scripts/lib.sh`: `ipc`, `gshort`, `hc`, `beat`, `mark`, `cursor_to`, `glide`, `click`, `type_text`. В каждом дубле: 1 с покоя в начале, 1 с в конце, `mark` на ключевых моментах (in/out для монтажа). Действия медленнее, чем кажется нужным — ускорить в монтаже можно, замедлить нет.

Читать `reference/capture.md` перед первой записью.

### 4. Запись
```
bash $SKILL/scripts/prep-env.sh          # чистое окружение, проверка разрешения
bash $SKILL/scripts/record-take.sh promo/takes/01-reveal.sh
bash $SKILL/scripts/contact-sheet.sh promo/raw/01-reveal.mp4
bash $SKILL/scripts/restore-env.sh       # всегда, даже после ошибки
```
`record-take.sh` уходит на пустой воркспейс (`PROMO_WORKSPACE`, по умолчанию `name:promo`), пишет монитор, возвращается. Терминал с Claude в кадр не попадает.

После каждого дубля открыть `.png` contact sheet через Read и проверить: нет лишних окон/уведомлений/приватных данных, анимации завершены, нет рывков. Для точной проверки — `contact-sheet.sh <file> <sec>` (один кадр). Брак → поправить скрипт → перезаписать. Не переходить дальше с браком.

### 5. Монтаж
1. `cp -r $SKILL/templates/remotion promo/video && cd promo/video && npm i` (затем `npx remotion versions` — версии пакетов должны совпадать).
2. `bash $SKILL/scripts/normalize.sh promo/raw promo/video/public/clips` — CFR 60 fps, yuv420p, без звука.
3. Музыку пользователя положить в `public/`, выровнять громкость: `ffmpeg -i in -af loudnorm=I=-14:TP=-1.5:LRA=11 public/music.m4a`.
4. Заполнить `src/storyboard.ts` (сцены, `trim` по `.markers`, `zoom.origin` на виджет) и палитру в `src/theme.ts`.
5. Превью: `npx remotion studio` — отдать пользователю, сам в студию не ходить.

Лицензия Remotion: бесплатно для частных лиц и компаний до 3 сотрудников; иначе нужна платная лицензия — упомянуть, если пользователь не соло.

### 6. Рендер и проверка
```
npx remotion still Promo ../out/check-NNN.png --frame=NNN   # кадр на каждой границе сцен + середина
npx remotion render Promo ../out/promo-1080p.mp4 --codec=h264 --crf=16
npx remotion render Promo4K ../out/promo-4k.mp4 --codec=h264 --crf=18     # если запись ≥ 1440p
npx remotion render PromoVertical ../out/promo-9x16.mp4 --codec=h264 --crf=18
```
Проверить через Read кадры-стиллы: текст не обрезан, кириллица отрисована шрифтом Inter, зум не мылит (зум > 1.25 на 1080p-исходнике = мыло). Громкость: `ffmpeg -i out.mp4 -af ebur128 -f null - 2>&1 | tail -12` → Integrated ≈ −14 LUFS. Длительность: `ffprobe`.

### 7. Сдача
Пути к файлам, длительность, что сделать вручную (например, заменить временные подписи). `restore-env.sh` выполнен.
