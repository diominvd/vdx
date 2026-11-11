import QtQuick
import QtTest
import qs.config
import qs.kit

Item {
  width: 1000
  height: 700
  KitPicker {
    id: picker
    width: 900
    height: 450
    model: [{ key: "one", label: "First" }, { key: "two", label: "Second" }]
    selected: "one"
    onPicked: key => selected = key
  }
  KitSelect {
    id: select
    y: 460
    width: 600
    model: [{ label: "First", value: 1 }, { label: "Second", value: 2 }]
    current: 1
  }
  SignalSpy { id: activated; target: picker; signalName: "activated" }
  SignalSpy { id: selections; target: select; signalName: "picked" }
  TestCase {
    name: "PickerRegression"
    when: windowShown
    function named(item, label) {
      if (item.Accessible.name === label) return item;
      for (const child of item.children) {
        const found = named(child, label);
        if (found) return found;
      }
      return null;
    }
    function test_picker_keyboard_and_accessibility() {
      const second = named(picker, "Second");
      verify(second !== null);
      verify(second.activeFocusOnTab);
      second.forceActiveFocus(Qt.TabFocusReason);
      activated.clear();
      keyClick(Qt.Key_Space);
      compare(picker.selected, "two");
      verify(second.Accessible.checked);
      compare(activated.count, 0);
      keyClick(Qt.Key_Return);
      compare(activated.count, 1);
    }
    function test_closing_select_cannot_choose_again() {
      ShellSettings.motion = false;
      select.openChoices();
      verify(select.expanded);
      // Hold the last painted frame while the closing animation would run.
      select.expanded = false;
      select.reveal = 1;
      selections.clear();
      mouseClick(select, 40, Theme.rowHeight + select.spacing + Theme.navigationHeight * 1.5);
      compare(selections.count, 0);
      select.reveal = Qt.binding(() => select.expanded ? 1 : 0);
    }
  }
}
