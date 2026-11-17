.pragma library

// Plain rules shared by the event path and tests. App names are literal, not regexes.
function accepts(n, options) {
  const names = [n.app, n.desktop].map(s => String(s ?? "").trim().toLowerCase());
  // The desktop client can announce our bot's own messages: never reflect them.
  if (names.some(s => s.includes("telegram"))) return false;
  if (options.urgency === "critical" && n.urgency !== "critical") return false;
  if (options.urgency === "normal" && n.urgency !== "normal" && n.urgency !== "critical") return false;
  const apps = options.apps.split(",").map(s => s.trim().toLowerCase()).filter(s => s !== "");
  const matches = names.some(s => apps.includes(s));
  if (options.filter === "only") return matches;
  if (options.filter === "except") return !matches;
  return true;
}

function message(n, body) {
  return ["vdx · " + (n.app || "Notification"), n.summary, body ? n.body : ""].filter(s => s !== "").join("\n").slice(0, 4000);
}
