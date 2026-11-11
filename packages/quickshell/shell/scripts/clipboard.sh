#!/usr/bin/env bash
#
# clipboard.sh — clipboard history kept as plain files (text or PNG), newest
# first, so an image can be dragged straight out of the list.
#   watch            run `wl-paste --watch … store` (one per session: a lock)
#   store            stdin = the new selection (run by the watcher)
#   list             [{"id": "...", "kind": "text|image", "preview": "...", "path": "...", "time": 1700000000}, ...]
#   copy <id>        put the entry back on the clipboard (and on top)
#   delete <id>      {"ok": true}
#   clear            {"ok": true}
#   limit <n>        keep at most n entries, {"ok": true}
# Entries: $XDG_DATA_HOME/clipboard/<epoch-ns>-<hash>.{txt,png}; the limit in
# its `limit` file (100 by default). Password-manager copies are not kept.

set -uo pipefail
dir="${XDG_DATA_HOME:-$HOME/.local/share}/clipboard"

fail() {
  printf '{"ok":false,"error":"%s"}\n' "$1"
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "required command unavailable: $1"
}

mkdir -p -- "$dir" || fail "could not create clipboard history"

parse_limit() {
  [[ $1 =~ ^[0-9]{1,5}$ ]] || return 1
  local number=$((10#$1))
  (( number >= 1 && number <= 10000 )) || return 1
  printf '%s' "$number"
}

limit() {
  local saved normalized
  if [[ -r $dir/limit ]] && IFS= read -r saved < "$dir/limit" \
      && normalized=$(parse_limit "$saved"); then
    printf '%s\n' "$normalized"
  else
    printf '%s\n' 100
  fi
}

valid_id() { [[ $1 =~ ^[[:xdigit:]]{16}$ ]]; }

entry() {
  ENTRY=""
  local candidate
  for candidate in "$dir"/*-"$1".txt "$dir"/*-"$1".png; do
    [[ -f $candidate ]] || continue
    ENTRY=$candidate
    return 0
  done
  return 1
}

# Drop the oldest entries beyond the limit without splitting paths on spaces.
trim() {
  local keep count=0 record file
  keep=$(limit)
  find "$dir" -maxdepth 1 -type f \( -name '*.txt' -o -name '*.png' \) -printf '%T@ %p\0' \
    | sort -z -nr \
    | while IFS= read -r -d '' record; do
        file=${record#* }
        ((count += 1))
        if (( count > keep )); then rm -f -- "$file" || exit 1; fi
      done
}

case "${1:-}" in
  watch)
    need flock
    need wl-paste
    # A second watcher (an old shell's, not yet gone) would store everything twice.
    exec flock -n "$dir/.watch.lock" wl-paste --watch bash "$0" store
    ;;
  store)
    need flock
    need wl-paste
    need grep
    need mktemp
    need cat
    need sha1sum
    need date
    need rm
    need mv
    need find
    need sort
    exec 9>"$dir/.store.lock" || fail "could not lock clipboard history"
    flock 9 || fail "could not lock clipboard history"
    types=$(wl-paste --list-types 2>/dev/null) || fail "could not read clipboard types"
    grep -q 'x-kde-passwordManagerHint' <<<"$types" && exit 0
    tmp=$(mktemp "${TMPDIR:-/tmp}/clipboard.XXXXXX") || fail "could not create clipboard temporary file"
    trap '[[ -z ${tmp:-} ]] || rm -f -- "$tmp"' EXIT
    cat >"$tmp" || fail "could not read clipboard data"
    [[ -s $tmp ]] || exit 0
    if grep -q '^image/png' <<<"$types" && ! grep -q '^text/' <<<"$types"; then ext=png; else ext=txt; fi
    digest=$(sha1sum -- "$tmp") || fail "could not hash clipboard data"
    hash=${digest%% *}
    hash=${hash:0:16}
    [[ $hash =~ ^[[:xdigit:]]{16}$ ]] || fail "could not hash clipboard data"
    rm -f -- "$dir"/*-"$hash".* || fail "could not replace clipboard entry"
    stamp=$(date +%s%N) || fail "could not timestamp clipboard entry"
    mv -- "$tmp" "$dir/$stamp-$hash.$ext" || fail "could not store clipboard entry"
    tmp=""
    trim || fail "could not trim clipboard history"
    printf '%s\n' stored
    ;;
  list)
    need find
    need sort
    need jq
    need stat
    need head
    result=$(
      find "$dir" -maxdepth 1 -type f \( -name '*.txt' -o -name '*.png' \) -printf '%T@ %p\0' \
        | sort -z -nr \
        | while IFS= read -r -d '' record; do
            f=${record#* }
            name=${f##*/}
            id=${name%.*}
            id=${id#*-}
            [[ $f == *.png ]] && kind=image || kind=text
            time=$(stat -c %Y -- "$f") || exit 1
            if [[ $kind == image ]]; then
              jq -cn --arg id "$id" --arg path "$f" --argjson t "$time" \
                '{id: $id, kind: "image", preview: "", path: $path, time: $t}'
            else
              head -c 400 -- "$f" \
                | jq -cRs --arg id "$id" --arg path "$f" --argjson t "$time" \
                    '{id: $id, kind: "text", preview: ., path: $path, time: $t}'
            fi
          done \
        | jq -cs .
    ) || fail "could not list clipboard history"
    printf '%s\n' "$result"
    ;;
  copy)
    need wl-copy
    valid_id "${2:-}" || fail "bad clipboard entry id"
    entry "$2" || fail "no such entry"
    if [[ $ENTRY == *.png ]]; then
      wl-copy --type image/png <"$ENTRY" || fail "could not copy clipboard entry"
    else
      wl-copy <"$ENTRY" || fail "could not copy clipboard entry"
    fi
    printf '%s\n' '{"ok":true}'
    ;;
  delete)
    need rm
    valid_id "${2:-}" || fail "bad clipboard entry id"
    if entry "$2"; then rm -f -- "$ENTRY" || fail "could not delete clipboard entry"; fi
    printf '%s\n' '{"ok":true}'
    ;;
  clear)
    need find
    need rm
    find "$dir" -maxdepth 1 -type f \( -name '*.txt' -o -name '*.png' \) -print0 \
      | while IFS= read -r -d '' file; do rm -f -- "$file" || exit 1; done \
      || fail "could not clear clipboard history"
    printf '%s\n' '{"ok":true}'
    ;;
  limit)
    normalized=$(parse_limit "${2:-}") || fail "limit must be from 1 to 10000"
    printf '%s\n' "$normalized" >"$dir/limit" || fail "could not save clipboard limit"
    trim || fail "could not trim clipboard history"
    printf '%s\n' '{"ok":true}'
    ;;
  *)
    printf '%s\n' '{"ok":false,"error":"usage: clipboard.sh store|list|copy <id>|delete <id>|clear|limit <n>"}'
    exit 1
    ;;
esac
