import QtQuick
import QtTest
import qs.config
import qs.kit
import qs.modules.notifications

Item {
  width: 800; height: 1600
  TestTelegramPage { id: page; width: parent.width }
  TestCase {
    name: "TelegramPage"
    when: windowShown
    function row(label) { return Array.from(page.children).find(c => c.label === label); }
    function init() {
      TelegramService.busy = false;
      TelegramService.configured = false;
      TelegramService.connected = false;
      TelegramService.pairUrl = "";
      TelegramService.calls = [];
      ModuleSettings.values = {};
      page.width = 800;
    }
    function test_connect_clears_masked_field_and_rejects_overlap() {
      const input = row("Bot token").trailing[0];
      compare(input.echoMode, TextInput.Password);
      input.text = "dummy-token";
      TelegramService.busy = true;
      page.connectBot();
      compare(input.text, "dummy-token");
      verify(!input.enabled);
      TelegramService.busy = false;
      input.accepted();
      compare(input.text, "");
      compare(TelegramService.calls, ["connect"]);
    }
    function test_pairing_and_delivery_need_connection() {
      verify(row("Confirm your chat").needs !== "");
      verify(row("Forward notifications").needs !== "");
      TelegramService.pairUrl = "https://t.me/test_bot?start=test";
      compare(row("Confirm your chat").needs, "");
      TelegramService.connected = true;
      compare(row("Forward notifications").needs, "");
      row("Forward notifications").trailing[0].toggled();
      compare(ModuleSettings.get("telegram", "enabled", false), true);
      page.reset();
      compare(ModuleSettings.get("telegram", "enabled", false), false);
      verify(TelegramService.connected);
      verify(!page.changed);
    }
    function test_styles_and_narrow_fields_data() {
      return [{tag:"strict-round", material:false, sharp:false}, {tag:"strict-sharp", material:false, sharp:true},
              {tag:"material-round", material:true, sharp:false}, {tag:"material-sharp", material:true, sharp:true}];
    }
    function test_styles_and_narrow_fields(data) {
      ShellSettings.material = data.material;
      ShellSettings.corners = data.sharp ? "sharp" : "round";
      page.width = 340;
      wait(100);
      for (const label of ["Bot token", "Application names"]) {
        const r = row(label), input = r.trailing[0];
        verify(r.stacked);
        verify(input.width > 0);
        verify(Math.abs(input.width - r.width) < 1);
      }
    }
  }
}
