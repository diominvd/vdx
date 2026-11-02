import QtQuick
import QtTest
import TestQuickshell
import qs.kit

TestCase {
  name: "SettingsIndex"
  Component { id: factory; TestSettingsIndex {} }

  function test_duplicate_rows_for_one_destination_are_collapsed() {
    const index = createTemporaryObject(factory, this);
    index.indexed = [
      {entry: {label: "Text size", target: "fonts:size", where: "Fonts"}, label: "textsize", aliases: [], hint: ["shell"], where: ["fonts"]},
      {entry: {label: "Text size", target: "fonts:size", where: "Fonts › TEXT SIZE"}, label: "textsize", aliases: [], hint: ["text"], where: ["fonts", "text", "size"]},
      {entry: {label: "Text size", target: "modules:clock", where: "Clock"}, label: "textsize", aliases: [], hint: ["clock"], where: ["clock"]}
    ];
    const hits = index.search("text size");
    compare(hits.length, 2);
    compare(hits[0].target, "fonts:size");
    compare(hits[1].target, "modules:clock");
  }

  function test_hint_search_uses_cached_words() {
    const index = createTemporaryObject(factory, this);
    index.indexed = [
      {entry: {label: "Shortcut", target: "apps:keybinds", where: "Apps"}, label: "shortcut", aliases: [], hint: ["keyboard", "binding"], where: ["apps"]}
    ];
    compare(index.search("key bind")[0].target, "apps:keybinds");
  }
}
