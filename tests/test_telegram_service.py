"""Production notification ingestion, forwarding rules and worker state in JS.

Node supplies the JS engine only; no Telegram connection or desktop is used.
"""
import json
import shutil
import subprocess
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL


@unittest.skipUnless(shutil.which("node"), "Node is not installed")
class TelegramService(unittest.TestCase):
    def run_js(self, source):
        result = subprocess.run(["node", "-e", source], capture_output=True, text=True, timeout=8)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def test_rule_combinations_and_literal_app_names(self):
        rules = (SHELL / "modules/notifications/telegram_rules.js").read_text().replace(".pragma library", "")
        result = self.run_js(rules + '''
const n = {app: "Build [prod]", desktop: "org.build", urgency: "normal"};
const all = {urgency:"all", filter:"all", apps:""};
console.log(JSON.stringify([
  accepts(n, all), accepts({...n, app:"Telegram Desktop"}, all),
  accepts({...n, desktop:"org.telegram.desktop"}, all),
  accepts(n, {...all, filter:"only", apps:" BUILD [PROD],other "}),
  accepts(n, {...all, filter:"only", apps:".*"}),
  accepts(n, {...all, filter:"except", apps:"ORG.BUILD"}),
  accepts(n, {...all, filter:"only"}), accepts(n, {...all, urgency:"critical"}),
  accepts({...n, urgency:"critical"}, {...all, urgency:"normal"}),
  accepts({...n, urgency:"low"}, {...all, urgency:"normal"}),
  message({app:"Build", summary:"Done", body:"Secret"}, false),
  message({app:"Build", summary:"Done", body:"Text"}, true)
]));
''')
        self.assertEqual(result, [True, False, False, True, False, False, False, False, True, False,
                                  "vdx · Build\nDone", "vdx · Build\nDone\nText"])

    def test_ingest_skips_startup_and_duplicates_but_forwards_new_and_replaced(self):
        source = (SHELL / "modules/notifications/NotificationsService.qml").read_text()
        result = self.run_js('''
let forwardReady = false;
let state = {items:[], tracked:true, lastId:0, epoch:0};
const root = {historyMax:100};
let sent = [];
const TelegramService = {enqueue: rows => sent.push(...rows)};
const ModuleSettings = {get: () => true};
''' + qml_function(source, "ingest") + '''
const old = {id:1, app:"Build", summary:"Old", body:"", urgency:"normal"};
ingest([old]);
const startup = sent.length;
ingest([old]);
ingest([old, {...old,id:2,summary:"New"}]);
ingest([old, {...old,id:2,summary:"New"}]);
ingest([old, {...old,id:2,summary:"Updated"}]);
state.items = [];
ingest([old, {...old,id:2,summary:"Updated"}]);
console.log(JSON.stringify({startup, sent:sent.map(n=>n.summary), remaining:state.items.length}));
''')
        self.assertEqual(result, {"startup": 0, "sent": ["New", "Updated"], "remaining": 0})

    def fixture(self):
        source = (SHELL / "modules/notifications/TelegramService.qml").read_text()
        funcs = "\n".join(qml_function(source, name) for name in
                          ("run", "refresh", "enqueue", "schedule", "drain", "consumeReply"))
        return '''
let enabled=true, busy=false, error="", status="", queue=[], readQueued=false, nextSendAt=0;
let stateKnown=false, configured=false, connected=false, username="", pairUrl="";
const queueMax=50, queueAgeMs=60000, sendGapMs=1100;
const root={script:"/unused/telegram.py"};
const proc={running:false, started:false, payload:"", processStopped:true, replyReady:false};
let timerStarts=0;
const sendDelay={interval:0, restart:()=>timerStarts++};
const ModuleSettings={get:(m,k,f)=>f};
const Rules={accepts:()=>true,message:n=>n.summary};
const Markup={plain:s=>s};
''' + funcs

    def test_queue_bound_replacement_expiry_and_idle_work(self):
        result = self.run_js(self.fixture() + '''
schedule();
const idle=timerStarts;
busy=true;
enqueue(Array.from({length:70},(_,i)=>({key:String(i),summary:String(i)})));
enqueue([{key:"69",summary:"Updated"}]);
const bounded=queue.length, updated=queue[49].text;
queue[0].at=Date.now()-70000;
busy=false;
drain();
const payload=JSON.parse(proc.payload);
console.log(JSON.stringify({idle,bounded,updated,remaining:queue.length,payload,busy}));
''')
        self.assertEqual(result, {"idle": 0, "bounded": 50, "updated": "Updated", "remaining": 48,
                                  "payload": {"text": "21", "silent": False}, "busy": True})

    def test_completion_waits_for_exit_clears_secret_and_no_retry_on_error(self):
        result = self.run_js(self.fixture() + '''
run("connect",{token:"sensitive"});
const overlap=run("test",{});
proc.pendingReply={ok:true,configured:true,connected:false,username:"test_bot",pairUrl:"https://t.me/test_bot?start=code"};
proc.replyReady=true;
consumeReply();
const beforeExit=busy;
proc.running=false;proc.processStopped=true;
consumeReply();
const after={busy,payload:proc.payload,configured,connected};
queue=[{key:"x",at:Date.now(),text:"private"}];
run("send",{text:"private"});
proc.running=false;proc.processStopped=true;proc.replyReady=true;
proc.pendingReply={ok:false,error:"Rate limited",retryAfter:30};
consumeReply();
console.log(JSON.stringify({overlap,beforeExit,after,busy,error,queue:queue.length,cooldown:nextSendAt>Date.now()+29000}));
''')
        self.assertEqual(result, {"overlap": False, "beforeExit": True,
                                  "after": {"busy": False, "payload": "", "configured": True, "connected": False},
                                  "busy": False, "error": "Rate limited", "queue": 0, "cooldown": True})

    def test_process_start_failure_clears_payload_busy_and_queue(self):
        source = (SHELL / "modules/notifications/TelegramService.qml").read_text()
        block = qml_block(source, "    onRunningChanged: {").split(":", 1)[1]
        result = self.run_js(self.fixture() + '''
root.consumeReply=consumeReply;
run("send",{text:"private"});
queue=[{text:"pending"}];
proc.running=false;
(function () { with(proc) ''' + block + ''' })();
console.log(JSON.stringify({busy,error,payload:proc.payload,queue:queue.length}));
''')
        self.assertEqual(result, {"busy": False, "error": "Could not start Telegram helper", "payload": "", "queue": 0})

    def test_pairing_failure_refreshes_expiry_without_repeating_the_pair_request(self):
        result = self.run_js(self.fixture() + '''
run("pair",{});
proc.pendingReply={ok:false,error:"Chat link expired"};
proc.processStopped=true;proc.replyReady=true;proc.running=false;
consumeReply();
const checking=busy && proc.action === "status";
proc.pendingReply={ok:true,configured:true,connected:false,username:"test_bot",pairUrl:""};
proc.processStopped=true;proc.replyReady=true;proc.running=false;
consumeReply();
console.log(JSON.stringify({checking,busy,error,pairUrl,configured,connected}));
''')
        self.assertEqual(result, {"checking": True, "busy": False, "error": "Chat link expired",
                                  "pairUrl": "", "configured": True, "connected": False})

    def test_opening_page_keeps_delivery_error_and_disabled_queue_does_no_work(self):
        result = self.run_js(self.fixture() + '''
error="Delivery failed";
refresh();
proc.pendingReply={ok:true,configured:true,connected:true,username:"test_bot",pairUrl:""};
proc.processStopped=true;proc.replyReady=true;proc.running=false;
consumeReply();
enabled=false;
enqueue([{key:"new",summary:"private"}]);
schedule();drain();
console.log(JSON.stringify({error,busy,connected,queue:queue.length,timerStarts}));
''')
        self.assertEqual(result, {"error": "Delivery failed", "busy": False, "connected": True, "queue": 0, "timerStarts": 0})


if __name__ == "__main__":
    unittest.main()
