import QtQuick
import QtTest
import "settings_data.js" as SettingsData

TestCase {
  name: "SettingsData"

  function test_record_accepts_only_object_values() {
    compare(SettingsData.record(null), {});
    compare(SettingsData.record([]), {});
    compare(SettingsData.record("wrong"), {});
    compare(SettingsData.record({ width: 420 }), { width: 420 });
  }

  function test_string_map_discards_non_string_entries_without_mutating_source() {
    const source = { theme: "common/a.png", invalid: 42 };
    compare(SettingsData.stringMap(source), { theme: "common/a.png" });
    compare(source.invalid, 42);
    compare(SettingsData.stringMap(null), {});
  }

  function test_string_arrays_keep_only_strings() {
    compare(SettingsData.strings(["notice", 2, null, "music"]), ["notice", "music"]);
    compare(SettingsData.strings({ 0: "notice" }), []);
  }

  function test_custom_colours_accept_only_hex_values() {
    compare(SettingsData.colours(["#abc", "#112233", "bad", 3, "#12345678"]), ["#abc", "#112233"]);
  }

  function test_notification_rules_keep_only_usable_fields() {
    compare(SettingsData.notificationColourRules([
      { app: "Browser", colour: "blue" }, { app: 42, colour: "red" }, { app: "Player" }, null
    ]), [{ app: "Browser", colour: "blue" }]);
  }

  function test_numeric_and_typed_settings_fall_back_safely() {
    compare(SettingsData.integer(24, 4, 24, 12), 24);
    compare(SettingsData.integer(25, 4, 24, 12), 12);
    compare(SettingsData.integer(4.5, 4, 24, 12), 12);
    compare(SettingsData.integerMap({ cards: 12, controls: "16", bar: 99 }, 4, 24), { cards: 12, controls: 16 });
    compare(SettingsData.typed("false", true), true);
    compare(SettingsData.typed(null, "default"), "default");
    compare(SettingsData.typed({ bad: true }, { good: true }), { bad: true });
  }
}
