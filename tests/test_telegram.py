"""Telegram pairing, private storage and API boundaries; no real network or secrets."""
import importlib.util
import io
import json
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

SCRIPTS = Path(__file__).resolve().parents[1] / "packages/quickshell/shell/scripts"
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("vdx_telegram", SCRIPTS / "telegram.py")
tg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tg)
sys.path.pop(0)

TOKEN = "123456789:" + "x" * 35


class Telegram(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.env = Path(self.tmp.name) / "secrets/env"
        self.env.parent.mkdir()
        self.path = patch.object(tg, "SECRETS", self.env)
        self.path.start()
        self.addCleanup(self.path.stop)

    def connect(self):
        with patch.object(tg, "call", return_value={"is_bot": True, "username": "test_bot"}):
            return tg.connect({"token": TOKEN})

    def update(self, values, **fields):
        message = {"chat": {"id": 42, "type": "private"}, "from": {"id": 42, "is_bot": False},
                   "date": int(values["PAIR_CREATED"]), "text": "/start " + values["PAIR_CODE"]}
        message.update(fields)
        return {"update_id": 123, "message": message}

    def test_status_is_read_only_and_never_returns_credentials(self):
        self.assertFalse(tg.dispatch("status", {})["configured"])
        self.assertFalse(self.env.exists())
        self.connect()
        tg.save(dict(tg.credentials(), CHAT_ID="42"))
        reply = tg.dispatch("status", {})
        self.assertTrue(reply["connected"])
        self.assertNotIn(TOKEN, json.dumps(reply))
        self.assertNotIn("CHAT_ID", json.dumps(reply))

    def test_connect_preserves_other_secrets_and_permissions_and_resets_old_chat(self):
        original = "# credentials\nexport OTHER_KEY='keep this'\nVDX_TELEGRAM_EXTRA=keep\n"
        self.env.write_text(original + "export VDX_TELEGRAM_CHAT_ID='91'\n")
        result = self.connect()
        self.assertEqual(stat.S_IMODE(self.env.stat().st_mode), 0o600)
        self.assertTrue(self.env.read_text().startswith(original))
        self.assertNotIn("CHAT_ID", tg.credentials())
        self.assertTrue(result["pairUrl"].startswith("https://t.me/test_bot?start="))
        self.assertFalse(result["connected"])
        tg.dispatch("disconnect", {})
        self.assertEqual(self.env.read_text(), original)

    def test_failed_token_validation_keeps_old_connection(self):
        self.connect()
        before = self.env.read_text()
        with patch.object(tg, "call", side_effect=tg.TelegramError("Rejected")):
            with self.assertRaises(tg.TelegramError):
                tg.connect({"token": TOKEN})
        self.assertEqual(self.env.read_text(), before)
        with self.assertRaises(tg.TelegramError):
            tg.connect({"token": "$(do-not-execute)"})

    def test_pair_requires_our_fresh_code_from_private_human_chat(self):
        self.connect()
        values = tg.credentials()
        bad = [self.update(values, text="/start wrong"), self.update(values, text="/start"),
               self.update(values, chat={"type": "group", "id": -42}),
               self.update(values, date=int(values["PAIR_CREATED"]) - 1),
               self.update(values, **{"from": {"id": 42, "is_bot": True}}),
               self.update(values, **{"from": {"id": 43, "is_bot": False}})]
        with patch.object(tg, "call", return_value=bad):
            with self.assertRaises(tg.TelegramError):
                tg.pair(values)
        self.assertNotIn("CHAT_ID", tg.credentials())
        with patch.object(tg, "call", return_value=[self.update(values)]) as api:
            result = tg.pair(tg.credentials())
        self.assertEqual(api.call_args.args[2]["offset"], 124)
        self.assertTrue(result["connected"])
        self.assertEqual(result["pairUrl"], "")
        self.assertEqual(tg.credentials()["CHAT_ID"], "42")
        self.assertFalse(any(k.startswith("PAIR_") for k in tg.credentials()))

    def test_pair_expires_without_network_request(self):
        self.connect()
        values = tg.credentials()
        with patch.object(tg.time, "time", return_value=int(values["PAIR_CREATED"]) + tg.PAIR_SECONDS), patch.object(tg, "call") as api:
            self.assertEqual(tg.status(values)["pairUrl"], "")
            with self.assertRaises(tg.TelegramError):
                tg.pair(values)
            api.assert_not_called()

    def test_atomic_write_failure_keeps_original_and_cleans_temporary_file(self):
        self.env.write_text("OTHER=keep\n")
        with patch.object(tg.os, "replace", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                tg.save({"TOKEN": TOKEN})
        self.assertEqual(self.env.read_text(), "OTHER=keep\n")
        self.assertEqual(list(self.env.parent.iterdir()), [self.env])

    def test_send_plain_text_bound_and_no_link_previews(self):
        values = {"TOKEN": TOKEN, "CHAT_ID": "42"}
        with patch.object(tg, "call", return_value={"message_id": 1}) as api:
            tg.send(values, {"text": "<b>&hello\n" + "😀" * 5000, "silent": True})
        token, method, payload = api.call_args.args
        self.assertEqual((token, method), (TOKEN, "sendMessage"))
        self.assertLessEqual(len(payload["text"].encode("utf-16-le")), 8000)
        self.assertTrue(payload["text"].startswith("<b>&hello\n"))
        self.assertNotIn("parse_mode", payload)
        self.assertTrue(payload["disable_notification"])
        self.assertEqual(payload["link_preview_options"], {"is_disabled": True})

    def test_unpaired_send_never_calls_api(self):
        with patch.object(tg, "call") as api:
            with self.assertRaises(tg.TelegramError):
                tg.send({"TOKEN": TOKEN}, {"text": "private"})
            api.assert_not_called()

    def test_http_errors_and_rate_limit_never_echo_token_url(self):
        for code in (401, 403, 409, 429, 500, 302):
            with self.subTest(code=code):
                exc = urllib.error.HTTPError("https://api.telegram.org/bot" + TOKEN, code, TOKEN, {},
                                             io.BytesIO(b'{"parameters":{"retry_after":17}}'))
                with patch.object(tg.urllib.request, "build_opener") as opener:
                    opener.return_value.open.side_effect = exc
                    with self.assertRaises(tg.TelegramError) as caught:
                        tg.call(TOKEN, "getMe")
                    self.assertNotIn(TOKEN, str(caught.exception))
                    self.assertEqual(caught.exception.retry_after, 17 if code == 429 else 0)
                    self.assertTrue(exc.fp.closed)

    def test_network_error_and_bad_reply_are_sanitised(self):
        with patch.object(tg.urllib.request, "build_opener") as opener:
            opener.return_value.open.side_effect = urllib.error.URLError(TOKEN)
            with self.assertRaises(tg.TelegramError) as caught:
                tg.call(TOKEN, "getMe")
            self.assertNotIn(TOKEN, str(caught.exception))
        for raw in (b'[]', b'null', b'{"ok":false}', b'not json'):
            with patch.object(tg.urllib.request, "build_opener") as opener:
                opener.return_value.open.return_value.__enter__.return_value.read.return_value = raw
                with self.assertRaises(tg.TelegramError):
                    tg.call(TOKEN, "getMe")

    def test_corrupt_env_and_invalid_input_return_json_without_secret(self):
        self.env.write_text("VDX_TELEGRAM_TOKEN='" + TOKEN)
        for command, raw in (("status", ""), ("connect", "[]"), ("send", "{")):
            output = io.StringIO()
            with patch.object(sys, "argv", ["telegram.py", command]), patch.object(sys, "stdin", io.StringIO(raw)), patch.object(sys, "stdout", output):
                with self.assertRaises(SystemExit) as exit_code:
                    tg.main()
            self.assertEqual(exit_code.exception.code, 1)
            self.assertFalse(json.loads(output.getvalue())["ok"])
            self.assertNotIn(TOKEN, output.getvalue())


if __name__ == "__main__":
    unittest.main()
