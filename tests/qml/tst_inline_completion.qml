import QtQuick
import QtTest
import qs.kit

Item {
  width: 500; height: 200

  KitInput {
    id: field
    width: 300
    completions: ["Telegram", "Terminal", "Firefox"]
  }
  KitInput { id: next; y: 70; width: 300 }
  SignalSpy { id: saved; target: field; signalName: "accepted" }
  SignalSpy { id: edited; target: field; signalName: "textEdited" }

  TestCase {
    name: "InlineCompletion"
    when: windowShown

    function enter(text) {
      field.input.forceActiveFocus();
      field.text = text;
      field.input.cursorPosition = text.length;
      field.input.deselect();
    }
    function init() {
      field.echoMode = TextInput.Normal;
      enter("");
      saved.clear(); edited.clear();
    }
    function test_tab_accepts_suffix_without_saving_or_leaving_field() {
      enter("te");
      compare(field.completionSuffix, "legram");
      keyClick(Qt.Key_Tab);
      compare(field.text, "Telegram");
      verify(field.input.activeFocus);
      compare(field.completionSuffix, "");
      compare(saved.count, 0);
      compare(edited.count, 1);
      keyClick(Qt.Key_Return);
      compare(saved.count, 1);
    }
    function test_tab_without_completion_keeps_normal_focus_navigation() {
      enter("unknown");
      compare(field.completionSuffix, "");
      keyClick(Qt.Key_Tab);
      tryCompare(next.input, "activeFocus", true);
      compare(field.text, "unknown");
    }
    function test_no_hint_while_editing_middle_selecting_or_unfocused() {
      enter("Te");
      field.input.cursorPosition = 1;
      compare(field.completionSuffix, "");
      field.input.cursorPosition = 2;
      compare(field.completionSuffix, "legram");
      field.input.selectAll();
      compare(field.completionSuffix, "");
      field.input.deselect();
      next.input.forceActiveFocus();
      compare(field.completionSuffix, "");
    }
    function test_empty_and_password_fields_never_offer_a_completion() {
      compare(field.completionSuffix, "");
      enter("Te");
      field.echoMode = TextInput.Password;
      compare(field.completionSuffix, "");
      verify(!field.acceptCompletion());
      compare(field.text, "Te");
    }
    function test_shift_tab_does_not_accept_suggestion() {
      enter("Te");
      keyClick(Qt.Key_Tab, Qt.ShiftModifier);
      compare(field.text, "Te");
      compare(edited.count, 0);
    }
  }
}
