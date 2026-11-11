#!/usr/bin/env python3
"""VirusTotal for the scanner (apps/virustotal and its bar module). One JSON
object per command.

    virustotal.py scan <target> [wait]   a sha256, a URL or a file path: what VirusTotal knows
                                         {"ok", "known", "kind", "target", "sha256", "name", "size",
                                          "stats", "reputation", "detections", "link"}
                                         a file it has never seen: {"ok", "known": false, "sha256", "size"}
    virustotal.py upload <path> [wait]   sends a file (up to 32 MB) and waits for the verdict; same reply

`wait` is how many seconds a new analysis may take (default 90, 10 to 600).

The key comes from VIRUSTOTAL_API_KEY or ~/.config/secrets/env. Only
`upload` sends a file's contents, and the shell asks before it does.
Errors: {"ok": false, "error": "..."}."""
import base64, hashlib, json, os, re, sys, time, urllib.error, urllib.parse, urllib.request, uuid
from pathlib import Path
from backend import out, fail

API = "https://www.virustotal.com/api/v3"
GUI = "https://www.virustotal.com/gui"
SECRETS = Path.home() / ".config/secrets/env"
MAX_UPLOAD = 32 * 1024 * 1024
WAIT = 90                                   # seconds a fresh analysis may take (the argument `wait`)
STATS = ("malicious", "suspicious", "undetected", "harmless", "timeout")

KEY = ""


class NotFound(Exception):
    pass


def key():
    if os.environ.get("VIRUSTOTAL_API_KEY"):
        return os.environ["VIRUSTOTAL_API_KEY"]
    try:
        m = re.search(r'^(?:export\s+)?VIRUSTOTAL_API_KEY=["\']?([^"\'\n]+)', SECRETS.read_text(), re.M)
    except OSError:
        m = None
    if not m:
        fail("no VIRUSTOTAL_API_KEY in ~/.config/secrets/env")
    return m.group(1).strip()


def call(method, path, body=None, headers=None):
    req = urllib.request.Request(API + path, data=body, method=method)
    req.add_header("x-apikey", KEY)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            try:
                response = json.loads(r.read())
            except ValueError as e:
                raise RuntimeError("invalid response from VirusTotal") from e
            if not isinstance(response, dict):
                raise RuntimeError("invalid response from VirusTotal")
            return response
    except urllib.error.HTTPError as e:
        if e.code == 404:
            raise NotFound() from e
        if e.code in (401, 403):
            raise RuntimeError("VirusTotal refuses the API key") from e
        if e.code == 429:
            raise RuntimeError("too many requests: the free key allows 4 a minute") from e
        try:
            msg = json.loads(e.read())["error"]["message"]
        except Exception:
            msg = f"HTTP {e.code}"
        raise RuntimeError(msg) from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"no connection to VirusTotal: {e.reason}") from e


def response_field(response, field, kind):
    data = response.get("data") if isinstance(response, dict) else None
    value = data.get(field) if isinstance(data, dict) else None
    if not isinstance(value, kind):
        raise RuntimeError("invalid response from VirusTotal")
    return value


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def wait_analysis(aid):
    end = time.monotonic() + WAIT
    while True:
        attrs = response_field(call("GET", f"/analyses/{aid}"), "attributes", dict)
        if attrs.get("status") == "completed":
            return attrs
        if time.monotonic() >= end:
            raise RuntimeError("VirusTotal is still analysing: look again in a minute")
        time.sleep(3)


def report(kind, target, sha, attrs, link):
    stats = attrs.get("last_analysis_stats") or attrs.get("stats") or {}
    results = attrs.get("last_analysis_results") or attrs.get("results") or {}
    if not isinstance(stats, dict) or not isinstance(results, dict) or any(not isinstance(r, dict) for r in results.values()):
        raise RuntimeError("invalid response from VirusTotal")
    if any(type(stats.get(k, 0)) is not int or stats.get(k, 0) < 0 for k in STATS):
        raise RuntimeError("invalid response from VirusTotal")
    found = [{"engine": e, "category": r.get("category"), "result": r.get("result") or ""}
             for e, r in results.items() if r.get("category") in ("malicious", "suspicious")]
    found.sort(key=lambda d: (d["category"] != "malicious", d["engine"]))
    return {"ok": True, "known": True, "kind": kind, "target": target, "sha256": sha,
            "name": attrs.get("meaningful_name") or attrs.get("url") or target,
            "size": attrs.get("size"), "stats": {k: stats.get(k, 0) for k in STATS},
            "reputation": attrs.get("reputation"), "detections": found[:50], "link": link}


def file_lookup(sha, target, size):
    try:
        attrs = response_field(call("GET", f"/files/{sha}"), "attributes", dict)
    except NotFound:
        return {"ok": True, "known": False, "kind": "file", "target": target, "sha256": sha, "size": size}
    return report("file", target, sha, attrs, f"{GUI}/file/{sha}")


def url_scan(url):
    uid = base64.urlsafe_b64encode(url.encode()).decode().rstrip("=")
    link = f"{GUI}/url/{hashlib.sha256(url.encode()).hexdigest()}"
    try:
        attrs = response_field(call("GET", f"/urls/{uid}"), "attributes", dict)
    except NotFound:
        body = urllib.parse.urlencode({"url": url}).encode()
        aid = response_field(call("POST", "/urls", body, {"Content-Type": "application/x-www-form-urlencoded"}), "id", str)
        attrs = wait_analysis(aid)
    return report("url", url, None, attrs, link)


def scan(target):
    t = target.strip()
    if re.fullmatch(r"[0-9a-fA-F]{64}", t):
        return file_lookup(t.lower(), t.lower(), None)
    if re.match(r"https?://", t, re.I):
        return url_scan(t)
    path = Path(os.path.expanduser(t))
    if not path.is_file():
        fail(f"no file, URL or hash: {t}")
    return file_lookup(sha256_file(path), str(path), path.stat().st_size)


def upload(target):
    path = Path(os.path.expanduser(target))
    if not path.is_file():
        fail(f"no such file: {target}")
    if path.stat().st_size > MAX_UPLOAD:
        fail("over 32 MB: the upload limit here")
    with path.open("rb") as source:
        content = source.read(MAX_UPLOAD + 1)
    if len(content) > MAX_UPLOAD:
        fail("over 32 MB: the upload limit here")
    sha = hashlib.sha256(content).hexdigest()
    boundary = uuid.uuid4().hex
    name = path.name.replace('"', "").replace("\r", "").replace("\n", "")
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{name}"\r\n'
            f"Content-Type: application/octet-stream\r\n\r\n").encode() + content \
           + f"\r\n--{boundary}--\r\n".encode()
    del content
    aid = response_field(call("POST", "/files", body, {"Content-Type": f"multipart/form-data; boundary={boundary}"}), "id", str)
    return report("file", str(path), sha, wait_analysis(aid), f"{GUI}/file/{sha}")


def main():
    global KEY, WAIT
    if len(sys.argv) not in (3, 4) or sys.argv[1] not in ("scan", "upload"):
        fail("usage: virustotal.py scan|upload <target> [wait]")
    if len(sys.argv) == 4:
        try:
            WAIT = min(600, max(10, int(sys.argv[3])))
        except ValueError:
            fail("wait must be a number of seconds")
    KEY = key()
    try:
        out(scan(sys.argv[2]) if sys.argv[1] == "scan" else upload(sys.argv[2]))
    except (RuntimeError, OSError) as e:
        fail(str(e))


if __name__ == "__main__":
    main()
