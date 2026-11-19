# Запись

## Перед первой записью

- Разрешение монитора: `hyprctl monitors -j | jq '.[] | {name, width, height, refreshRate, scale}'`. Для 4K-рендера нужен исходник ≥ 2560×1440. Scale ≠ 1 → кадр пишется в физическом разрешении, координаты `cursor_to` — в логических.
- Один монитор пишется: `PROMO_MONITOR` (по умолчанию — сфокусированный).
- Обои: те, что в ролике. Если на обоях текст/лица — спросить.
- Частота: рекордер пишет 60 fps CFR. Монитор 144 Гц не мешает.

## prep-env.sh делает (в рантайме, откатывается restore-env.sh)

- `hyprctl keyword misc:disable_hyprland_logo true`, `cursor:inactive_timeout 0`
- уведомления: `makoctl mode -a do-not-disturb` / `swaync-client -dn` / `dunstctl set-paused true` — что найдено
- сохраняет текущий воркспейс в `$XDG_RUNTIME_DIR/qs-promo/state`

Что prep-env **не** делает и надо проверить руками: открытые окна на промо-воркспейсе, автостарт мессенджеров, громкие системные звуки.

## Курсор

- Курсор виден в записи (`gpu-screen-recorder -cursor yes`). Если сцене курсор не нужен — `cursor_to` в угол экрана в начале дубля.
- `glide x y ms` двигает плавно (ease-in-out, 60 шагов/с) через `hyprctl dispatch movecursor`. Без ydotool клик невозможен — тогда только IPC/шорткаты.

## Тайминг

- Анимации Quickshell обычно 150–400 мс. `beat` после действия ≥ длительность анимации + 300 мс.
- `mark name` пишет `секунды-от-старта name` в `.markers`. Монтаж берёт `trim` из маркеров.
- Если открытие панели запускает сетевой запрос (Wi-Fi scan, погода) — прогреть: открыть/закрыть до `mark in`.

## Типичный брак

| Симптом на contact sheet | Причина | Решение |
|---|---|---|
| Окно терминала в кадре | дубль стартовал до переключения воркспейса | `beat 0.5` после `hc dispatch workspace` уже есть в record-take; проверить `PROMO_WORKSPACE` |
| Чёрные/битые первые кадры | рекордер не прогрелся | record-take ждёт 1 с; увеличить `PROMO_WARMUP` |
| Рывки | VFR | только gpu-screen-recorder `-fm cfr`; wf-recorder → normalize.sh |
| Панель «недооткрыта» в mark | анимация длиннее beat | увеличить beat |
