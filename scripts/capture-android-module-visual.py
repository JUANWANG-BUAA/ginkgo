#!/usr/bin/env python3
"""Receive bounded synthetic QA screenshots on loopback only; no school traffic."""
import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
parser.add_argument("--device")
parser.add_argument("--adb", type=Path)
args = parser.parse_args()
if args.device and (not re.fullmatch(r"emulator-\d+", args.device) or not args.adb):
    parser.error("system capture requires an isolated emulator and an adb path")
args.output.mkdir(parents=True, exist_ok=True)

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        # Capture Android directly without converting the Flutter surface for
        # a long sequence of screenshots. No device state is changed.
        if not args.device or not re.fullmatch(r"/[a-z0-9-]+\.png", self.path):
            self.send_error(400)
            return
        try:
            result = subprocess.run(
                [str(args.adb), "-s", args.device, "exec-out", "screencap", "-p"],
                capture_output=True, check=True, timeout=15,
            )
            content = result.stdout
            if not content.startswith(b"\x89PNG\r\n\x1a\n") or len(content) > 12 * 1024 * 1024:
                raise ValueError("invalid screenshot")
            (args.output / self.path[1:]).write_bytes(content)
        except (subprocess.SubprocessError, ValueError):
            self.send_error(500)
            return
        self.send_response(204)
        self.end_headers()

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
