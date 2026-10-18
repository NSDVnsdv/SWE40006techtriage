"""Level 1 placeholder for TechTriage.

Shows which environment a server is and which commit its image was built
from, so the repo -> GitHub Actions -> GHCR -> EC2 chain can be checked
before the real Flask app exists. Level 3 replaces this file and the
Dockerfile with the real application.

Standard library only, so the image needs no pip install.

Level 2 (monitoring) adds:
- One JSON access-log line per request on stdout, e.g.
  {"type": "access", "method": "GET", "path": "/", "status": 200, "duration_ms": 1.42}
  On Production, Docker ships stdout to CloudWatch Logs and metric filters
  turn these lines into request count, latency and 5xx metrics. The Level 3
  Gunicorn app must keep this same log format so the metrics keep working.
- Two test-only routes, /_fault/500 and /_fault/slow?ms=N, used to prove the
  5xx and latency alarms fire. They return 404 unless FAULT_INJECTION=1.
"""

import html
import json
import os
import signal
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

APP_ENV = os.environ.get("APP_ENV", "unknown")
APP_VERSION = os.environ.get("APP_VERSION", "unknown")
PORT = int(os.environ.get("PORT", "8000"))
# Off unless the server's .env sets FAULT_INJECTION=1 (alarm testing only).
FAULT_INJECTION = os.environ.get("FAULT_INJECTION", "0") == "1"
SLOW_MAX_MS = 3000

# One colour per environment so screenshots are easy to tell apart.
ENV_COLOURS = {
    "development": "#2563eb",
    "testing": "#d97706",
    "staging": "#7c3aed",
    "production": "#15803d",
}

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>TechTriage | {env}</title>
<style>
  body {{ margin: 0; font-family: system-ui, sans-serif; background: #f4f4f5; color: #18181b; }}
  header {{ background: {colour}; color: #fff; padding: 2rem 1rem; text-align: center; }}
  header h1 {{ margin: 0; font-size: 2.5rem; text-transform: uppercase; letter-spacing: .05em; }}
  header p {{ margin: .5rem 0 0; opacity: .9; }}
  main {{ max-width: 40rem; margin: 2rem auto; padding: 0 1rem; }}
  table {{ width: 100%; border-collapse: collapse; background: #fff; }}
  th, td {{ text-align: left; padding: .75rem; border-bottom: 1px solid #e4e4e7; }}
  th {{ width: 9rem; }}
  code {{ font-size: 1rem; word-break: break-all; }}
  .note {{ color: #52525b; font-size: .9rem; }}
</style>
</head>
<body>
<header>
  <h1>{env}</h1>
  <p>TechTriage placeholder</p>
</header>
<main>
  <table>
    <tr><th>Environment</th><td><code>{env}</code></td></tr>
    <tr><th>Commit (SHA)</th><td><code>{version}</code></td></tr>
    <tr><th>Short SHA</th><td><code>{short}</code></td></tr>
  </table>
  <p class="note">Level 1 pipeline check. The real TechTriage app replaces this page in Level 3.
  Machine-readable: <a href="/version">/version</a> and <a href="/health">/health</a>.</p>
</main>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    server_version = "TechTriagePlaceholder"

    def do_GET(self):
        self._started = time.perf_counter()
        path, _, query = self.path.partition("?")
        self._path = path
        if FAULT_INJECTION and path == "/_fault/500":
            self._json(500, {"error": "simulated server error (FAULT_INJECTION=1)"})
        elif FAULT_INJECTION and path == "/_fault/slow":
            try:
                ms = int(parse_qs(query).get("ms", ["800"])[0])
            except ValueError:
                ms = 800
            ms = max(0, min(ms, SLOW_MAX_MS))
            time.sleep(ms / 1000)
            self._json(200, {"status": "ok", "slept_ms": ms})
        elif path == "/":
            self._send(200, "text/html; charset=utf-8", PAGE.format(
                env=html.escape(APP_ENV),
                version=html.escape(APP_VERSION),
                short=html.escape(APP_VERSION[:7]),
                colour=ENV_COLOURS.get(APP_ENV, "#3f3f46"),
            ))
        elif path == "/health":
            self._json(200, {"status": "ok", "environment": APP_ENV})
        elif path == "/version":
            self._json(200, {"environment": APP_ENV, "version": APP_VERSION})
        else:
            self._json(404, {"error": "not found"})

    def _json(self, status, body):
        self._send(status, "application/json", json.dumps(body))

    def _send(self, status, content_type, body):
        data = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)
        self._access_log(status)

    def _access_log(self, status):
        duration_ms = (time.perf_counter() - self._started) * 1000
        print(json.dumps({
            "type": "access",
            "method": self.command,
            "path": self._path,
            "status": status,
            "duration_ms": round(duration_ms, 2),
        }), flush=True)

    def log_message(self, format, *args):
        # Replace the default plain-text stderr log with the JSON line above.
        pass


def main():
    # PID 1 in a container ignores SIGTERM unless a handler is set, which
    # would make every `docker compose down` wait 10 seconds.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(json.dumps({
        "type": "startup",
        "message": "TechTriage placeholder started",
        "environment": APP_ENV,
        "version": APP_VERSION,
        "port": PORT,
        "fault_injection": FAULT_INJECTION,
    }), flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
