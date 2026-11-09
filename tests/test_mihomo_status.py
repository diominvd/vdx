"""mihomo.sh --status: a server of a provider is not in /proxies, so its ping
and provider come from /providers/proxies (the live activity shows that ping)."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "packages/quickshell/shell/scripts/mihomo.sh"
NODE = "🇫🇮 #2 Финляндия"

ROUTES = {
    "/configs": {"mode": "rule"},
    "/proxies/Proxies": {"type": "Selector", "now": NODE},
    "/proxies": {"proxies": {"DIRECT": {"history": [{"delay": 5}]}}},
    "/providers/proxies": {"providers": {
        "other": {"proxies": [{"name": "x", "history": [{"delay": 9}]}]},
        "main": {"proxies": [{"name": NODE, "history": [{"delay": 700}, {"delay": 123}]}]},
    }},
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = ROUTES.get(self.path)
        self.send_response(200 if body is not None else 404)
        self.end_headers()
        if body is not None:
            self.wfile.write(json.dumps(body).encode())

    def log_message(self, *args):
        pass


@unittest.skipUnless(shutil.which("curl") and shutil.which("jq"), "needs curl and jq")
class Status(unittest.TestCase):
    def status(self, routes):
        saved = dict(ROUTES)
        ROUTES.update(routes)
        self.addCleanup(lambda: (ROUTES.clear(), ROUTES.update(saved)))
        server = HTTPServer(("127.0.0.1", 0), Handler)
        self.addCleanup(server.server_close)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.shutdown)
        env = dict(os.environ, MIHOMO_API=f"http://127.0.0.1:{server.server_port}")
        out = subprocess.run(["bash", str(SCRIPT), "--status"], env=env, capture_output=True,
                             text=True, check=True).stdout
        return json.loads(out)

    def test_a_providers_server_has_its_provider_and_last_ping(self):
        status = self.status({})
        self.assertEqual((status["node"], status["provider"], status["delay"]), (NODE, "main", 123))

    def test_a_builtin_node_reads_its_ping_from_proxies(self):
        status = self.status({"/proxies/Proxies": {"type": "Selector", "now": "DIRECT"}})
        self.assertEqual((status["provider"], status["delay"]), ("", 5))

    def test_no_ping_history_is_zero(self):
        status = self.status({"/providers/proxies": {"providers": {"main": {"proxies": [{"name": NODE}]}}}})
        self.assertEqual((status["provider"], status["delay"]), ("main", 0))


if __name__ == "__main__":
    unittest.main()
