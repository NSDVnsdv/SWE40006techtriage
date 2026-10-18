"""Level 1 placeholder for TechTriage.

Shows which environment a server is and which commit its image was built
from, so the repo -> GitHub Actions -> GHCR -> EC2 chain can be checked
before the real Flask app exists. Level 3 replaces this file and the
Dockerfile with the real application.

Standard library only, so the image needs no pip install.
"""

import html
import json
import os
import signal
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

APP_ENV = os.environ.get("APP_ENV", "unknown")
APP_VERSION = os.environ.get("APP_VERSION", "unknown")
PORT = int(os.environ.get("PORT", "8000"))

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
        path = self.path.split("?", 1)[0]
        if path == "/":
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


def main():
    # PID 1 in a container ignores SIGTERM unless a handler is set, which
    # would make every `docker compose down` wait 10 seconds.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"TechTriage placeholder: env={APP_ENV} version={APP_VERSION} port={PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
