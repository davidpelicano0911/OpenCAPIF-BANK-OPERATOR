#!/usr/bin/env python3
"""
app.py — Servidor dos dois portais da demo CAPIF (biblioteca padrão, sem Flask).

Páginas:
  /            → landing com links para os dois portais
  /operadora   → portal da Operadora (Provider)
  /banco       → portal do Banco (Invoker)

Endpoints (estado partilhado → ligam os portais ATRAVÉS do CAPIF):
  GET  /api/state    (snapshot do estado partilhado, para a barra de estado)
  POST /api/op/register   /api/op/publish   /api/op/audit
  POST /api/bk/register   /api/bk/discover   /api/bk/token
  POST /api/bk/check  (body: {"phone": "..."})    /api/bk/check-notoken
  POST /api/reset

Correr:  python3 web_demo/app.py     →  http://localhost:8090
"""

import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from capif_flow import CapifFlow

PORT = 8090
HERE = os.path.dirname(os.path.abspath(__file__))
STATIC = os.path.join(HERE, "static")

flow = CapifFlow()

PAGES = {"/": "landing.html", "/operadora": "operadora.html", "/banco": "banco.html"}
CT = {".html": "text/html", ".css": "text/css", ".js": "application/javascript"}


class H(BaseHTTPRequestHandler):
    def log_message(self, fmt, *a):
        print("  [web]", fmt % a)

    def _json(self, status, obj):
        b = json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _file(self, path):
        with open(path, "rb") as f:
            b = f.read()
        self.send_response(200)
        self.send_header("Content-Type", CT.get(os.path.splitext(path)[1], "text/plain"))
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _body(self):
        n = int(self.headers.get("Content-Length", 0) or 0)
        if not n:
            return {}
        try:
            return json.loads(self.rfile.read(n))
        except Exception:
            return {}

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/api/state":
            self._json(200, flow.snapshot())
            return
        if path in PAGES:
            self._file(os.path.join(STATIC, PAGES[path]))
            return
        name = os.path.basename(path)
        full = os.path.join(STATIC, name)
        if os.path.isfile(full):
            self._file(full)
        else:
            self._json(404, {"error": "not_found", "path": self.path})

    def do_POST(self):
        global flow
        p = self.path
        try:
            if p == "/api/op/register":
                self._json(200, flow.op_register())
            elif p == "/api/op/publish":
                self._json(200, flow.op_publish())
            elif p == "/api/op/audit":
                self._json(200, flow.op_audit())
            elif p == "/api/bk/register":
                self._json(200, flow.bk_register())
            elif p == "/api/bk/discover":
                self._json(200, flow.bk_discover())
            elif p == "/api/bk/token":
                self._json(200, flow.bk_token())
            elif p == "/api/bk/check":
                phone = self._body().get("phone", "").strip()
                self._json(200, flow.bk_check(phone))
            elif p == "/api/reset":
                flow = CapifFlow()
                reset_sh = os.path.join(HERE, "..", "reset_demo.sh")
                if os.path.isfile(reset_sh):
                    try:
                        subprocess.run(["bash", reset_sh], timeout=30, capture_output=True)
                    except Exception:
                        pass
                self._json(200, {"ok": True, "message": "reposto"})
            else:
                self._json(404, {"error": "not_found"})
        except Exception as e:
            # Return a card-shaped result so the UI shows a readable error
            # (with the real cause) instead of "undefined".
            msg = str(e)
            if "CERTIFICATE_VERIFY_FAILED" in msg or "unknown ca" in msg:
                msg = ("TLS certificate mismatch between Register and CAPIF Core. "
                       "The stack's CA is inconsistent — do a clean restart "
                       "(clean_capif_docker_services.sh -a && run.sh). Details: " + msg)
            elif "Connection refused" in msg or "Max retries" in msg:
                msg = ("Could not reach CAPIF Core (capifcore:443). Is the stack up "
                       "and nginx not Restarting? Details: " + msg)
            print(f"  [web] ERROR on {p}: {e}", flush=True)
            self._json(500, {"ok": False, "title": "Error", "summary": msg})


if __name__ == "__main__":
    print(f"Portais da demo CAPIF:")
    print(f"  Operadora → http://localhost:{PORT}/operadora")
    print(f"  Banco     → http://localhost:{PORT}/banco")
    print("  Ctrl+C para parar.")
    HTTPServer(("0.0.0.0", PORT), H).serve_forever()
