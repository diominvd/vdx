import QtQuick
import QtTest
import qs.config
import qs.kit
import qs.modules.notifications

Item {
  width: 800; height: 1600
  TelegramSettings { id: page; width: parent.width }
  TelegramForwarding { id: forwarding; width: 600 }
  TestNotificationsPage { id: notifications; width: 600; visible: false }
  TestCase {
    name: "TelegramPage"
    when: windowShown
    function row(label) { return Array.from(page.children).find(c => c.label === label); }
    function init() {
      TelegramService.stateKnown = true;
      TelegramService.busy = false;
      TelegramService.configured = false;
      TelegramService.connected = false;
      TelegramService.pairUrl = "";
      TelegramService.calls = [];
      TelegramService.error = "";
      TelegramService.status = "";
      TelegramService.username = "";
      ModuleSettings.values = {};
      page.editingBot = false;
      page.tokenEntry = false;
      page.chatOpened = false;
      page.manageConnection = false;
      page.connecting = false;
      page.linkError = "";
      row("Bot token").trailing[0].text = "";
      page.revealGroup = "";
      page.width = 800;
      const fold = forwarding.children.find(c => c.isReorderList);
      fold.open = "";
    }
    function test_connect_clears_masked_field_and_rejects_overlap() {
      page.tokenEntry = true;
      const input = row("Bot token").trailing[0];
      compare(input.echoMode, TextInput.Password);
      input.text = "dummy-token";
      TelegramService.busy = true;
      page.connectBot();
      compare(input.text, "dummy-token");
      verify(!input.enabled);
      TelegramService.stateKnown = true;
      TelegramService.busy = false;
      input.accepted();
      compare(input.text, "");
      compare(TelegramService.calls, ["connect"]);
    }
    function test_pairing_and_delivery_need_connection() {
      verify(!row("Forward notifications").visible);
      verify(row("Forward notifications").needs !== "");
      TelegramService.connected = true;
      TelegramService.configured = true;
      compare(row("Forward notifications").needs, "");
      verify(row("Forward notifications").visible);
      row("Forward notifications").trailing[0].toggled();
      compare(ModuleSettings.get("telegram", "enabled", false), true);
      page.reset();
      compare(ModuleSettings.get("telegram", "enabled", false), false);
      verify(TelegramService.connected);
      verify(!page.changed);
    }
    function test_guided_setup_shows_one_stage_at_a_time() {
      compare(page.setupStep, 0);
      verify(row("Create a bot").visible);
      verify(!row("Bot token").visible);
      row("Already have a bot?").trailing[0].clicked();
      compare(page.setupStep, 1);
      verify(row("Bot token").visible);
      verify(!row("Create a bot").visible);
      row("Bot token").trailing[0].text = "dummy-token";
      page.connectBot();
      TelegramService.configured = true;
      TelegramService.username = "test_bot";
      TelegramService.pairUrl = "https://t.me/test_bot?start=test";
      TelegramService.busy = false;
      compare(page.setupStep, 2);
      verify(!row("Bot token").visible);
      verify(row("Open your bot's chat").visible);
      page.chatOpened = true; // external Telegram interaction is the platform boundary
      compare(page.setupStep, 3);
      row("After pressing Start").trailing[1].clicked();
      compare(TelegramService.calls, ["connect", "pair"]);
      TelegramService.connected = true;
      TelegramService.busy = false;
      compare(page.setupStep, 4);
      verify(row("Telegram bot").visible);
      verify(row("Forward notifications").visible);
      compare(ModuleSettings.get("telegram", "enabled", false), false);
    }
    function test_failed_bot_change_keeps_retry_and_cancel_available() {
      TelegramService.connected = true;
      TelegramService.configured = true;
      page.manageConnection = true;
      row("Change bot").trailing[0].clicked();
      row("Bot token").trailing[0].text = "dummy-token";
      page.connectBot();
      TelegramService.error = "Invalid token";
      TelegramService.busy = false;
      compare(page.setupStep, 1);
      compare(row("Bot token").trailing[0].text, "");
      row("Check the bot").trailing[0].clicked();
      compare(page.setupStep, 4);
      verify(TelegramService.connected);
    }
    function test_expired_link_can_be_renewed_without_token_entry() {
      TelegramService.configured = true;
      compare(page.setupStep, 2);
      verify(row("Renew the chat link").visible);
      verify(!row("Bot token").visible);
      row("Renew the chat link").trailing[0].clicked();
      compare(TelegramService.calls, ["renew"]);
      TelegramService.pairUrl = "https://t.me/test_bot?start=renewed";
      TelegramService.busy = false;
      verify(row("Open your bot's chat").visible);
      verify(!row("Renew the chat link").visible);
    }
    function test_disconnect_requires_confirmation() {
      TelegramService.connected = true;
      TelegramService.configured = true;
      page.manageConnection = true;
      const button = row("Disconnect Telegram").trailing[0];
      button.clicked();
      compare(TelegramService.calls.length, 0);
      button.clicked();
      compare(TelegramService.calls, ["disconnect"]);
    }
    function descendants(item) {
      let result = [];
      for (const child of item.children || []) result = result.concat([child], descendants(child));
      return result;
    }
    function test_connection_steps_and_rule_visibility() {
      page.tokenEntry = true;
      verify(row("Bot token").visible);
      verify(!row("Telegram bot").visible);
      verify(!row("Include message text").visible);
      TelegramService.configured = true;
      TelegramService.connected = true;
      TelegramService.username = "test_bot";
      verify(!row("Bot token").visible);
      verify(row("Telegram bot").visible);
      ModuleSettings.set("telegram", "enabled", true);
      verify(row("Include message text").visible);
      verify(!row("Application names").visible);
      ModuleSettings.set("telegram", "filter", "only");
      verify(row("Application names").visible);
    }
    function test_fold_is_lazy_and_can_open_while_forwarding_is_off() {
      verify(!descendants(forwarding).some(c => typeof c.connectBot === "function"));
      forwarding.open("telegram-rules");
      tryVerify(() => descendants(forwarding).some(c => typeof c.connectBot === "function"));
      const options = descendants(forwarding).find(c => typeof c.connectBot === "function");
      verify(options.showRules);
      compare(forwarding.rowOf("telegram-rules").text, "RULES");
      compare(ModuleSettings.get("telegram", "enabled", false), false);
      tryVerify(() => descendants(forwarding).some(c => c.source !== undefined && String(c.source).endsWith("assets/telegram.svg")));
      const logo = descendants(forwarding).find(c => c.source !== undefined && String(c.source).endsWith("assets/telegram.svg"));
      tryCompare(logo, "status", Image.Ready);
      forwarding.children.find(c => c.isReorderList).open = "";
      tryVerify(() => !descendants(forwarding).some(c => typeof c.connectBot === "function"));
    }
    function test_notifications_reset_preserves_bot_and_live_activity() {
      TelegramService.configured = true;
      TelegramService.connected = true;
      ModuleSettings.values = {notifications:{badge:"count",appear:"live"},
        "notifications/badge":"count", "notifications/appear":"live", "telegram/enabled":true, "telegram/apps":"Build"};
      verify(notifications.changed);
      notifications.reset();
      compare(ModuleSettings.get("telegram", "enabled", false), false);
      compare(ModuleSettings.get("telegram", "apps", ""), "");
      compare(ModuleSettings.get("notifications", "badge", "off"), "off");
      compare(ModuleSettings.get("notifications", "appear", "card"), "live");
      verify(TelegramService.connected);
      verify(TelegramService.configured);
      verify(!notifications.changed);
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
