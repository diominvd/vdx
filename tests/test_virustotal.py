"""VirusTotal uses the uploaded snapshot and validates remote response shapes."""
import hashlib
import importlib.util
import io
import contextlib
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "packages/quickshell/shell/scripts"
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("virustotal_backend", SCRIPTS / "virustotal.py")
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


class VirusTotal(unittest.TestCase):
    def test_upload_hash_belongs_to_uploaded_bytes_when_file_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sample"
            path.write_bytes(b"original")

            def post(method, route, body, headers):
                self.assertEqual((method, route), ("POST", "/files"))
                self.assertIn(b"original", body)
                path.write_bytes(b"changed")
                return {"data": {"id": "analysis"}}

            with patch.object(backend, "call", side_effect=post), \
                 patch.object(backend, "wait_analysis", return_value={}):
                result = backend.upload(str(path))
            self.assertEqual(result["sha256"], hashlib.sha256(b"original").hexdigest())

    def test_invalid_json_or_nonobject_api_response_is_a_protocol_error(self):
        for data in (b"[]", b"null", b"invalid"):
            with self.subTest(data=data), patch.object(backend.urllib.request, "urlopen", return_value=io.BytesIO(data)):
                with self.assertRaisesRegex(RuntimeError, "response"):
                    backend.call("GET", "/test")

    def test_analysis_deadline_uses_monotonic_time(self):
        responses = [{"data": {"attributes": {"status": "queued"}}},
                     {"data": {"attributes": {"status": "completed"}}}]
        with patch.object(backend, "WAIT", 3), patch.object(backend, "call", side_effect=responses), \
             patch.object(backend.time, "time", side_effect=[0, -100]), \
             patch.object(backend.time, "monotonic", side_effect=[0, 4]), patch.object(backend.time, "sleep"):
            with self.assertRaisesRegex(RuntimeError, "still analysing"):
                backend.wait_analysis("id")

    def test_malformed_lookup_fields_and_stats_are_protocol_errors(self):
        for response in ({"data": None}, {"data": {"attributes": []}},
                         {"data": {"attributes": {"stats": {"malicious": "many"}}}},
                         {"data": {"attributes": {"results": {"engine": None}}}}):
            with self.subTest(response=response), patch.object(backend, "call", return_value=response):
                with self.assertRaisesRegex(RuntimeError, "response"):
                    backend.scan("a" * 64)

    def test_upload_rechecks_limit_after_file_grows(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sample"
            path.write_bytes(b"large")
            before_growth = path.stat()
            path.write_bytes(b"growing contents")
            with patch.object(backend, "MAX_UPLOAD", 8), patch.object(Path, "stat", return_value=before_growth), \
                 patch.object(backend, "call") as call, contextlib.redirect_stdout(io.StringIO()), \
                 self.assertRaises(SystemExit) as exited:
                backend.upload(str(path))
            self.assertEqual(exited.exception.code, 1)
            call.assert_not_called()


if __name__ == "__main__":
    unittest.main()
