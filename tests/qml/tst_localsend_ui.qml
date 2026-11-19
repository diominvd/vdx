import QtQuick
import QtTest
import qs.config
import qs.apps.localsend
import qs.apps.files

Item {
  width: 1100; height: 680
  LocalSend { id: app; width: parent.width; height: parent.height }

  TestCase {
    name: "LocalSendUi"
    when: windowShown

    function descendants(item) {
      let result = [];
      for (const child of item.children || []) {
        result.push(child);
        result = result.concat(descendants(child));
      }
      return result;
    }
    function sendPage() { return descendants(app).find(item => typeof item.addPaths === "function"); }
    function init() {
      app.page = "send";
      LocalSendService.calls = [];
      LocalSendService.transfers.clear();
      LocalSendService.incomingRequests.clear();
      LocalSendService.devices.clear();
      LocalSendService.devices.append({fingerprint: "phone", alias: "Nearby phone", address: "192.168.1.2", deviceType: "mobile", available: true});
      LocalSendService.deviceRevision++;
      tryVerify(() => sendPage() !== undefined);
      sendPage().draft.queue = [];
      sendPage().draft.fingerprint = "";
    }
    function test_draft_survives_lazy_navigation_and_send() {
      let page = sendPage();
      page.addPaths([{path: "/tmp/report.pdf", size: 1024}]);
      page.addPaths(["/tmp/report.pdf"]);
      compare(page.queue.length, 1);
      page.draft.fingerprint = "phone";
      app.page = "transfers";
      tryVerify(() => sendPage() === undefined);
      app.page = "send";
      tryVerify(() => sendPage() !== undefined);
      page = sendPage();
      compare(page.queue.length, 1);
      compare(page.fingerprint, "phone");
      page.send();
      compare(LocalSendService.calls.length, 1);
      compare(LocalSendService.calls[0].paths[0], "/tmp/report.pdf");
      compare(app.page, "transfers");
      app.page = "send";
      tryVerify(() => sendPage() !== undefined);
      compare(sendPage().queue.length, 0);
    }
    function test_picker_result_survives_page_destruction() {
      sendPage().pick();
      app.page = "transfers";
      tryVerify(() => sendPage() === undefined);
      FilesService.finish([{path: "/tmp/late.pdf", size: 1024}]);
      app.page = "send";
      tryVerify(() => sendPage() !== undefined);
      compare(sendPage().queue.length, 1);
      compare(sendPage().queue[0].name, "late.pdf");
    }
    function test_incoming_selection_and_decline() {
      LocalSendService.incomingRequests.append({sessionId: "request", alias: "Nearby phone", expiresAt: Date.now() + 60000,
        files: [{fileId: "first", fileName: "report.pdf", size: 1024}, {fileId: "second", fileName: "photo.jpg", size: 2048}]});
      app.page = "incoming";
      tryVerify(() => descendants(app).some(item => typeof item.selectedIds === "function"));
      const page = descendants(app).find(item => typeof item.selectedIds === "function");
      const files = LocalSendService.incomingRequests.get(0).files;
      compare(page.selectedIds("request", files).length, 2);
      page.toggle("request", "first", files);
      compare(page.selectedIds("request", files).join(","), "second");
      page.toggle("request", "first", files);
      compare(page.selectedIds("request", files).length, 2);
      const decline = descendants(page).find(item => item.Accessible && item.Accessible.name === "Decline files from Nearby phone");
      verify(decline !== undefined);
      decline.clicked();
      compare(LocalSendService.calls[0].action, "reject");
    }
    function test_accept_sends_only_checked_files() {
      LocalSendService.incomingRequests.append({sessionId: "request", alias: "Nearby phone", expiresAt: Date.now() + 60000,
        files: [{fileId: "first", fileName: "report.pdf", size: 1024}, {fileId: "second", fileName: "photo.jpg", size: 2048}]});
      app.page = "incoming";
      tryVerify(() => descendants(app).some(item => typeof item.selectedIds === "function"));
      const page = descendants(app).find(item => typeof item.selectedIds === "function");
      const file = descendants(page).find(item => item.title === "report.pdf");
      verify(file !== undefined);
      file.clicked();
      const accept = descendants(page).find(item => item.text === "Accept" && typeof item.clicked === "function");
      verify(!accept.disabled);
      accept.clicked();
      compare(LocalSendService.calls[0].action, "accept");
      compare(LocalSendService.calls[0].files.join(","), "second");
    }
    function test_transfer_metadata_handles_nested_models() {
      LocalSendService.transfers.append({transferId: "transfer", deviceAlias: "Nearby phone", direction: "send", state: "completed",
        error: "", transferredBytes: 1024, totalBytes: 1024, totalFiles: 0, files: [{fileId: "one", fileName: "report.pdf", size: 1024}]});
      app.page = "transfers";
      tryVerify(() => descendants(app).some(item => typeof item.details === "function"));
      const page = descendants(app).find(item => typeof item.details === "function");
      compare(page.details(LocalSendService.transfers.get(0)), "1 file · 1.0 KB");
    }
    function test_footer_stays_in_bounds_data() {
      return [{tag: "strict-narrow", material: false, width: 740},
        {tag: "strict-wide", material: false, width: 1100},
        {tag: "material-narrow", material: true, width: 740},
        {tag: "material-wide", material: true, width: 1100}];
    }
    function test_footer_stays_in_bounds(data) {
      ShellSettings.material = data.material;
      app.width = data.width;
      app.height = 460;
      wait(40);
      const page = sendPage();
      const send = descendants(page).find(item => item.text === "Send" && typeof item.clicked === "function");
      verify(send !== undefined);
      const at = send.mapToItem(app, 0, 0);
      verify(at.x >= 0 && at.y >= 0);
      verify(at.x + send.width <= app.width);
      verify(at.y + send.height <= app.height);
      verify(send.disabled);
    }
  }
}
