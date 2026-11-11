"""Notification markup keeps unknown entities literal while decoding known text."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.qml_runtime import SHELL, run_quickshell


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class Markup(unittest.TestCase):
    def test_known_unknown_and_out_of_range_entities(self):
        with tempfile.TemporaryDirectory(prefix="shell-markup-") as tmp:
            root = Path(tmp)
            shutil.copy(SHELL / "kit/markup.js", root / "markup.js")
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import "markup.js" as Markup
Scope {
  Timer { interval: 0; running: true; onTriggered: {
    console.warn("MARKUP_RESULT:" + JSON.stringify([
      Markup.plain("<b>Hello</b> &amp; &#x1f600; &#39;"),
      Markup.plain("&constructor; &__proto__; &unknown; &#1114112;"),
      Markup.plain("&lt;b&gt;plain&lt;/b&gt;"), Markup.plain(null)
    ]));
    Qt.quit();
  } }
}
''')
            output = run_quickshell(root)
            rows = [line.split("MARKUP_RESULT:", 1)[1] for line in output.splitlines() if "MARKUP_RESULT:" in line]
            self.assertEqual(len(rows), 1, output)
            self.assertEqual(json.loads(rows[0]), ["Hello & 😀 '",
                                                  "&constructor; &__proto__; &unknown; &#1114112;",
                                                  "<b>plain</b>", ""])


if __name__ == "__main__":
    unittest.main()
