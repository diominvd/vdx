import QtQuick
import QtTest
import qs.kit

TestCase {
  name: "ModuleSettings"
  function init() { TestModuleSettings.state.values = ({}) }

  function test_invalid_root_values_are_an_empty_store() {
    for (const value of [null, 4, "bad", []]) {
      TestModuleSettings.state.values = value;
      compare(TestModuleSettings.get("audio", "closeOnOpen", true), true);
      compare(TestModuleSettings.changed("audio"), false);
    }
  }

  function test_invalid_module_and_inherited_keys_use_fallbacks() {
    TestModuleSettings.state.values = ({ audio: null, broken: [] });
    compare(TestModuleSettings.get("audio", "enabled", false), false);
    compare(TestModuleSettings.get("broken", "enabled", false), false);
    compare(TestModuleSettings.get("audio", "toString", "safe"), "safe");
    compare(TestModuleSettings.get("toString", "enabled", "safe"), "safe");
  }

  function test_false_and_null_are_saved_values() {
    TestModuleSettings.state.values = ({ audio: { disabled: false, cleared: null } });
    compare(TestModuleSettings.get("audio", "disabled", true), false);
    compare(TestModuleSettings.get("audio", "cleared", "fallback"), null);
  }

  function test_array_readers_reject_bad_shapes_and_filter_string_entries() {
    TestModuleSettings.state.values = ({ audio: { list: "bad", names: ["one", 2, null, "two"] } });
    compare(TestModuleSettings.array("audio", "list", [1]), [1]);
    compare(TestModuleSettings.array("audio", "names", []), ["one", 2, null, "two"]);
    compare(TestModuleSettings.strings("audio", "names", []), ["one", "two"]);
  }

  function test_set_and_reset_repair_bad_state_and_remove_empty_module() {
    TestModuleSettings.state.values = null;
    TestModuleSettings.set("audio", "enabled", false);
    compare(TestModuleSettings.get("audio", "enabled", true), false);
    verify(TestModuleSettings.changed("audio"));
    TestModuleSettings.reset("audio", ["enabled"]);
    compare(TestModuleSettings.changed("audio"), false);
    verify(!Object.prototype.hasOwnProperty.call(TestModuleSettings.values, "audio"));
  }
}
