.pragma library

// Apps send markup: tags (<b>…</b>) and escaped characters (&#39;, &amp;, &quot;).
// Strip the tags, then decode the characters, so the text reads as typed.
// The notification centre and the island's notices both show app text this way.

var entities = { "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " " };

function plain(text) {
  return (text ?? "").replace(/<[^>]*>/g, "").replace(/&(#x[\da-f]+|#\d+|\w+);/gi, (m, e) => {
    if (e[0] === "#") {
      const code = e[1].toLowerCase() === "x" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return code <= 0x10ffff ? String.fromCodePoint(code) : m;   // past Unicode it throws: keep it as sent
    }
    const name = e.toLowerCase();
    return Object.prototype.hasOwnProperty.call(entities, name) ? entities[name] : m;
  });
}
