.pragma library

// Shape checks for values loaded from the user's JSON state. Keep the stored
// data untouched; callers get safe views and can still recover the file later.
function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function record(value) { return isRecord(value) ? value : ({}); }

function stringMap(value) {
  if (!isRecord(value)) return {};
  const safe = {};
  for (const key of Object.keys(value))
    if (typeof value[key] === "string") safe[key] = value[key];
  return safe;
}

function strings(value) {
  return Array.isArray(value) ? value.filter(item => typeof item === "string") : [];
}

function colours(value) {
  return strings(value).filter(hex => /^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(hex));
}

function notificationColourRules(value) {
  if (!Array.isArray(value)) return [];
  return value.filter(rule => isRecord(rule) && typeof rule.app === "string" && typeof rule.colour === "string")
    .map(rule => ({ app: rule.app, colour: rule.colour }));
}

function integer(value, minimum, maximum, fallback) {
  const number = Number(value);
  return Number.isFinite(number) && Math.floor(number) === number && number >= minimum && number <= maximum
    ? number : fallback;
}

function integerMap(value, minimum, maximum) {
  if (!isRecord(value)) return {};
  const safe = {};
  for (const key of Object.keys(value)) {
    const number = Number(value[key]);
    if (Number.isFinite(number) && Math.floor(number) === number && number >= minimum && number <= maximum)
      safe[key] = number;
  }
  return safe;
}

function typed(value, fallback) {
  if (typeof fallback === "boolean") return typeof value === "boolean" ? value : fallback;
  if (typeof fallback === "number") return typeof value === "number" && Number.isFinite(value) ? value : fallback;
  if (typeof fallback === "string") return typeof value === "string" ? value : fallback;
  if (Array.isArray(fallback)) return Array.isArray(value) ? value : fallback;
  if (isRecord(fallback)) return record(value);
  return value === undefined ? fallback : value;
}
