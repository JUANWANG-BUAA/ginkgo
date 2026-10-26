#!/usr/bin/env python3
"""Receive bounded synthetic QA screenshots on loopback only; no school traffic."""
import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_POST(self):
        if not re.fullmatch(r"/[a-z0-9-]+\.png", self.path):
            self.send_error(400)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_error(400)
            return
        if not 0 < length < 12 * 1024 * 1024:
            self.send_error(400)
            return
        content = self.rfile.read(length)
        if not content.startswith(b"\x89PNG\r\n\x1a\n"):
            self.send_error(400)
            return
        (args.output / self.path[1:]).write_bytes(content)
        self.send_response(204)
        self.end_headers()

HTTPServer(("127.0.0.1", 18765), Handler).serve_forever()
