#!/usr/bin/env python3
"""Extract Rust call hierarchy via rust-analyzer LSP; never infer targets by name."""

import argparse
import concurrent.futures
import json
import os
import subprocess
import threading
from pathlib import Path
from urllib.parse import unquote, urlparse


class Lsp:
    def __init__(self, root, log, binary):
        self.process = subprocess.Popen(
            [binary],
            cwd=root,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=log,
        )
        self.lock = threading.Lock()
        self.pending = {}
        self.counter = 0
        self.ready = threading.Event()
        self.status = {}
        threading.Thread(target=self.reader, daemon=True).start()

    def send(self, body):
        data = json.dumps(body).encode()
        with self.lock:
            self.process.stdin.write(
                f"Content-Length: {len(data)}\r\n\r\n".encode() + data
            )
            self.process.stdin.flush()

    def reader(self):
        try:
            while True:
                headers = {}
                while True:
                    line = self.process.stdout.readline()
                    if not line:
                        raise RuntimeError(
                            f"rust-analyzer exited: {self.process.poll()}"
                        )
                    if line == b"\r\n":
                        break
                    key, value = line.decode().split(":", 1)
                    headers[key.lower()] = value.strip()
                body = json.loads(
                    self.process.stdout.read(int(headers["content-length"]))
                )
                if "id" in body and ("result" in body or "error" in body):
                    future = self.pending.pop(body["id"], None)
                    if future:
                        if "error" in body:
                            future.set_exception(RuntimeError(str(body["error"])))
                        else:
                            future.set_result(body["result"])
                elif body.get("method") == "experimental/serverStatus":
                    self.status = body["params"]
                    if self.status.get("quiescent"):
                        self.ready.set()
                elif "id" in body:
                    result = None
                    if body.get("method") == "workspace/configuration":
                        result = [None] * len(body.get("params", {}).get("items", []))
                    self.send({"jsonrpc": "2.0", "id": body["id"], "result": result})
        except Exception as e:  # noqa: BLE001 - preserve LSP failures as explicit evidence
            for future in list(self.pending.values()):
                if not future.done():
                    future.set_exception(e)

    def request(self, method, params, timeout=90):
        with self.lock:
            self.counter += 1
            id = self.counter
            future = concurrent.futures.Future()
            self.pending[id] = future
        self.send({"jsonrpc": "2.0", "id": id, "method": method, "params": params})
        return future.result(timeout)

    def close(self):
        if self.process.poll() is not None:
            return
        try:
            self.request("shutdown", None, 10)
        finally:
            self.send({"jsonrpc": "2.0", "method": "exit", "params": None})
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--target", default="aarch64-linux-android")
    args = parser.parse_args()
    root = args.root.resolve()
    out = args.output.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    nodes = {}
    edges = []
    issues = []
    excluded = []

    def path(uri):
        p = Path(unquote(urlparse(uri).path))
        try:
            return p.relative_to(root).as_posix()
        except ValueError:
            return p.as_posix()

    def node(item):
        file = path(item["uri"])
        pos = item["selectionRange"]["start"]
        id = f"{file}:{pos['line'] + 1}:{pos['character']}"
        nodes[id] = {
            "id": id,
            "name": item["name"],
            "file": file,
            "line": pos["line"] + 1,
            "column": pos["character"],
            "endLine": item["range"]["end"]["line"] + 1,
            "kind": item.get("kind"),
            "detail": item.get("detail"),
            "language": "rust",
            "external": not file.startswith("rust/crates/"),
            "generated": "frb_generated" in file,
        }
        return id

    with out.with_suffix(".log").open("w") as log:
        binary = subprocess.check_output(
            ["rustup", "which", "rust-analyzer"], cwd=root, text=True
        ).strip()
        lsp = Lsp(root / "rust", log, binary)
        try:
            lsp.request(
                "initialize",
                {
                    "processId": os.getpid(),
                    "rootUri": (root / "rust").as_uri(),
                    "capabilities": {
                        "textDocument": {
                            "callHierarchy": {"dynamicRegistration": False},
                            "documentSymbol": {
                                "hierarchicalDocumentSymbolSupport": True
                            },
                        },
                        "experimental": {"serverStatusNotification": True},
                    },
                    "initializationOptions": {
                        "cargo": {"allTargets": False, "target": args.target},
                        "checkOnSave": False,
                        "procMacro": {"enable": False},
                        "diagnostics": {"enable": False},
                    },
                },
            )
            lsp.send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
            # Bounded readiness wait, reporting progress instead of mistaking an
            # unloaded workspace for an empty graph.
            for i in range(12):
                if lsp.ready.wait(10):
                    break
                print(f"Rust workspace loading ({(i + 1) * 10}s)", flush=True)
            if not lsp.ready.is_set():
                raise RuntimeError("rust-analyzer workspace did not become ready")
            files = [
                p
                for p in sorted((root / "rust/crates").rglob("*.rs"))
                if "tests" not in p.parts
                and "frb_generated" not in p.name
                and not p.name.endswith("_tests.rs")
            ]
            symbols = []

            def collect(items, file, parents=(), parent_kinds=()):
                for item in items:
                    names = parents + (item["name"],)
                    if any(n == "tests" or n.endswith("_tests") for n in names):
                        continue
                    if item["kind"] in (6, 12):
                        symbols.append((file, item, 11 in parent_kinds))
                    collect(
                        item.get("children", []),
                        file,
                        names,
                        parent_kinds + (item["kind"],),
                    )

            for i, file in enumerate(files):
                try:
                    collect(
                        lsp.request(
                            "textDocument/documentSymbol",
                            {"textDocument": {"uri": file.as_uri()}},
                        )
                        or [],
                        file,
                    )
                except Exception as e:  # noqa: BLE001 - preserve LSP failures as explicit evidence
                    issues.append(
                        {
                            "file": str(file.relative_to(root)),
                            "stage": "symbols",
                            "error": str(e),
                        }
                    )
                if i % 50 == 0:
                    print(f"Rust symbols {i + 1}/{len(files)}", flush=True)
            for i, (file, symbol, is_trait) in enumerate(symbols):
                try:
                    prepared = (
                        lsp.request(
                            "textDocument/prepareCallHierarchy",
                            {
                                "textDocument": {"uri": file.as_uri()},
                                "position": symbol["selectionRange"]["start"],
                            },
                        )
                        or []
                    )
                    if not prepared:
                        item = dict(symbol, uri=file.as_uri())
                        node(item)
                        excluded.append(
                            {
                                "file": str(file.relative_to(root)),
                                "name": symbol["name"],
                                "reason": "prepareCallHierarchy returned no item",
                            }
                        )
                    for item in prepared:
                        source = node(item)
                        for impl in (
                            (
                                lsp.request(
                                    "textDocument/implementation",
                                    {
                                        "textDocument": {"uri": item["uri"]},
                                        "position": item["selectionRange"]["start"],
                                    },
                                )
                                or []
                            )
                            if is_trait
                            else []
                        ):
                            uri = impl.get("targetUri", impl.get("uri"))
                            selection = impl.get(
                                "targetSelectionRange", impl.get("range")
                            )
                            target_id = f"{path(uri)}:{selection['start']['line'] + 1}:{selection['start']['character']}"
                            if target_id not in nodes:
                                node(
                                    {
                                        "uri": uri,
                                        "name": item["name"],
                                        "kind": item["kind"],
                                        "range": impl.get(
                                            "targetRange", impl.get("range")
                                        ),
                                        "selectionRange": selection,
                                    }
                                )
                            edges.append(
                                {
                                    "from": source,
                                    "to": target_id,
                                    "kind": "implementation",
                                    "resolved": True,
                                    "file": path(item["uri"]),
                                    "line": item["selectionRange"]["start"]["line"] + 1,
                                }
                            )
                        for call in (
                            lsp.request("callHierarchy/outgoingCalls", {"item": item})
                            or []
                        ):
                            target = node(call["to"])
                            for span in call["fromRanges"]:
                                edges.append(
                                    {
                                        "from": source,
                                        "to": target,
                                        "kind": "call",
                                        "resolved": True,
                                        "file": str(file.relative_to(root)),
                                        "line": span["start"]["line"] + 1,
                                        "column": span["start"]["character"],
                                    }
                                )
                except Exception as e:  # noqa: BLE001 - preserve LSP failures as explicit evidence
                    issues.append(
                        {
                            "file": str(file.relative_to(root)),
                            "name": symbol["name"],
                            "stage": "calls",
                            "error": str(e),
                        }
                    )
                if i % 100 == 0:
                    print(f"Rust hierarchy {i + 1}/{len(symbols)}", flush=True)
            version = subprocess.check_output([binary, "--version"], text=True).strip()
            out.write_text(
                json.dumps(
                    {
                        "tool": version,
                        "configuration": {
                            "allTargets": False,
                            "procMacro": False,
                            "target": args.target,
                            "tests": False,
                        },
                        "serverStatus": lsp.status,
                        "files": len(files),
                        "symbols": len(symbols),
                        "nodes": list(nodes.values()),
                        "edges": edges,
                        "issues": issues,
                        "unprepared": excluded,
                    },
                    ensure_ascii=False,
                )
            )
            print(
                f"Rust: {len(nodes)} symbols, {len(edges)} call sites, {len(issues)} errors, {len(excluded)} unprepared",
                flush=True,
            )
            if issues:
                raise SystemExit(1)
        finally:
            lsp.close()


if __name__ == "__main__":
    main()
