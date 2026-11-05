#!/usr/bin/env python3
"""Merge analyzer evidence and render the viewer; edges are never authored here."""

import argparse
import collections
import hashlib
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path

from check_snapshot import source_manifest

ROOT = Path(__file__).resolve().parents[2]


def group(file):
    parts = file.split("/")
    if file.startswith("flutter/lib/features/"):
        return "/".join(parts[2:4])
    if file.startswith("flutter/lib/src/rust/"):
        return "Dart FRB API"
    if file.startswith("flutter/lib/"):
        return "Dart/" + (parts[2] if len(parts) > 3 else "root")
    if file.startswith("rust/crates/"):
        return parts[2]
    if file.startswith("flutter/android/"):
        return "Android Kotlin"
    return "External"


def scan_kotlin(root):
    base = "flutter/android/app/src/main/kotlin"

    def scan(kind):
        r = subprocess.run(
            [
                "ast-grep",
                "run",
                "--lang",
                "kotlin",
                "--kind",
                kind,
                "--json=compact",
                base,
            ],
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
        )
        if r.returncode not in (0, 1):
            raise RuntimeError(r.stderr)
        return json.loads(r.stdout or "[]")

    nodes = []
    edges = []
    ranges = collections.defaultdict(list)
    for kind in ["function_declaration", "lambda_literal"]:
        for item in scan(kind):
            file = item["file"]
            span = item["range"]
            start = span["start"]["line"] + 1
            found = re.search(r"\bfun\s+(?:<[^>]+>\s*)?([\w.]+)\s*\(", item["text"])
            name = found.group(1) if found else f"<lambda @{start}>"
            id = f"kotlin:{file}:{span['byteOffset']['start']}"
            nodes.append(
                {
                    "id": id,
                    "name": name,
                    "file": file,
                    "line": start,
                    "endLine": span["end"]["line"] + 1,
                    "kind": kind,
                    "language": "kotlin",
                    "external": False,
                    "generated": False,
                }
            )
            ranges[file].append(
                (span["byteOffset"]["start"], span["byteOffset"]["end"], id)
            )
    for file, items in ranges.items():
        for start, end, id in items:
            parents = [p for p in items if p[0] <= start and p[1] >= end and p[2] != id]
            if parents:
                parent = min(parents, key=lambda p: p[1] - p[0])
                edges.append(
                    {
                        "from": parent[2],
                        "to": id,
                        "kind": "contains",
                        "resolved": True,
                        "file": file,
                        "line": next(n["line"] for n in nodes if n["id"] == id),
                    }
                )
    for call in scan("call_expression"):
        file = call["file"]
        span = call["range"]
        offset = span["byteOffset"]["start"]
        parents = [p for p in ranges[file] if p[0] <= offset < p[1]]
        if not parents:
            continue
        owner = min(parents, key=lambda p: p[1] - p[0])[2]
        # Retain the syntax, not a guessed function target.
        edges.append(
            {
                "from": owner,
                "to": None,
                "kind": "syntax-call",
                "resolved": False,
                "label": call["text"].split("\n")[0][:180],
                "file": file,
                "line": span["start"]["line"] + 1,
            }
        )
    return {
        "tool": subprocess.check_output(["ast-grep", "--version"], text=True).strip(),
        "nodes": nodes,
        "edges": edges,
        "files": len(ranges),
        "issues": [],
    }


def build(root, raw, out):
    recorded = json.loads((raw / "source-manifest.json").read_text())
    if recorded != source_manifest(root):
        raise SystemExit("Raw evidence is stale; run scripts/architecture/generate.py")
    dart = json.loads((raw / "dart.json").read_text())
    rust = json.loads((raw / "rust-android.json").read_text())
    kotlin = scan_kotlin(root)
    source_nodes = [*dart["nodes"], *rust["nodes"], *kotlin["nodes"]]
    byid = {}
    for n in source_nodes:
        file = n["file"]
        n["group"] = group(file)
        if n.get("external"):
            # No local SDK/cache/home paths in published evidence.
            n["file"] = re.sub(
                r"^.*?/(?:\.cargo/registry/src/[^/]+/|\.rustup/toolchains/[^/]+/lib/rustlib/src/rust/)",
                "external/",
                file,
            )
            if n["file"].startswith("/"):
                n["file"] = "external/" + Path(file).name
        byid[n["id"]] = n
    edges = [*dart["edges"], *rust["edges"], *kotlin["edges"]]
    # Pair only exact generated API module names with the corresponding exported
    # Rust function. Keep this separate from compiler-resolved calls.
    pairs = 0
    unpaired = []
    for d in dart["nodes"]:
        path = d["file"]
        if not path.startswith("flutter/lib/src/rust/api/") or d["kind"] != "FUNCTION":
            continue
        module = Path(path).relative_to("flutter/lib/src/rust/api").with_suffix(".rs")
        rustfile = f"rust/crates/ginkgo_flutter_bridge/src/api/{module}"
        candidates = [
            n
            for n in rust["nodes"]
            if n["file"] == rustfile
            and re.sub(r"_([a-z])", lambda m: m[1].upper(), n["name"]) == d["name"]
        ]
        if len(candidates) == 1:
            edges.append(
                {
                    "from": d["id"],
                    "to": candidates[0]["id"],
                    "kind": "ffi-pair",
                    "resolved": False,
                    "file": path,
                    "line": d.get("line", 1),
                    "label": "FRB generated module/name pair; not cross-language type resolution",
                }
            )
            pairs += 1
        else:
            unpaired.append(
                {"file": path, "name": d["name"], "matches": len(candidates)}
            )
    # Only the project is expandable. External targets are retained as boundary
    # leaves, and external-to-external relationships are intentionally excluded.
    edges = [
        e for e in edges if e["from"] in byid and not byid[e["from"]].get("external")
    ]
    keep = {n["id"] for n in source_nodes if not n.get("external")}
    keep.update(e["to"] for e in edges if e.get("to") in byid)
    nodes = sorted(
        (byid[id] for id in keep),
        key=lambda n: (n["language"], n["file"], n.get("line", 0), n["name"], n["id"]),
    )
    ids = {n["id"]: i for i, n in enumerate(nodes)}
    files = {}
    manifest = {}
    for n in nodes:
        if n.get("external") or n.get("generated"):
            continue
        p = root / n["file"]
        if not p.is_file():
            continue
        if n["file"] not in files:
            files[n["file"]] = p.read_text().splitlines()
    for n in nodes:
        n["id"] = ids[n["id"]]
    unique = {}
    for e in edges:
        e = dict(e)
        e["from"] = ids[e["from"]]
        e["to"] = ids.get(e.get("to"))
        e["label"] = str(e.get("label", ""))[:180]
        key = (e["from"], e["to"], e["kind"], e["file"], e["line"], e["label"])
        unique[key] = e
    edges = sorted(
        unique.values(),
        key=lambda e: (
            e["file"],
            e["line"],
            e["kind"],
            e["from"],
            e["to"] if e["to"] is not None else -1,
        ),
    )
    # Hash the full scanner scope, including files with no detected functions.
    manifest = source_manifest(root)
    spec = importlib.util.spec_from_file_location(
        "ginkgo_index", root / "scripts/generate-interface-index.py"
    )
    m = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = m
    spec.loader.exec_module(m)
    imports = m.dart_dependency_edges()
    fg = {}
    for a, b, _ in imports:
        fg.setdefault(a, set()).add(b)
    cargo = json.loads(
        subprocess.check_output(
            [
                "cargo",
                "metadata",
                "--offline",
                "--locked",
                "--no-deps",
                "--format-version",
                "1",
                "--manifest-path",
                str(root / "rust/Cargo.toml"),
            ],
            cwd=root,
        )
    )
    names = {p["name"] for p in cargo["packages"]}
    crate_edges = [
        {
            "from": p["name"],
            "to": d["name"],
            "kind": d["kind"] or "normal",
            "target": d["target"],
        }
        for p in cargo["packages"]
        for d in p["dependencies"]
        if d["name"] in names
    ]
    meta = {
        "revision": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=root, text=True
        ).strip(),
        "sourceFingerprint": hashlib.sha256(
            json.dumps(manifest, sort_keys=True).encode()
        ).hexdigest(),
        "tools": {"dart": dart["tool"], "rust": rust["tool"], "kotlin": kotlin["tool"]},
        "files": {
            "dart": dart["files"],
            "rust": rust["files"],
            "kotlin": kotlin["files"],
        },
        "rustConfiguration": rust["configuration"],
        "rustStatus": rust["serverStatus"],
        "issues": {
            "dart": dart["issues"],
            "rust": rust["issues"],
            "rustUnprepared": rust["unprepared"],
            "ffiUnpaired": unpaired,
        },
        "ffiPairs": pairs,
        "counts": dict(collections.Counter(e["kind"] for e in edges)),
        "fileCycles": m.strongly_connected(fg),
        "directoryCycles": m.strongly_connected(m.dart_dependency_graph()),
    }
    data = {
        "meta": meta,
        "nodes": nodes,
        "edges": edges,
        "sources": files,
        "imports": imports,
        "crateEdges": crate_edges,
    }
    out.mkdir(parents=True, exist_ok=True)
    (out / "graph-data.js").write_text(
        "window.GINKGO_GRAPH = "
        + json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace(
            "</", "<\\/"
        )
        + ";\n"
    )
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (out / "analysis-summary.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2) + "\n"
    )
    print(
        json.dumps(
            {
                "nodes": len(nodes),
                "edges": len(edges),
                "kinds": meta["counts"],
                "ffiPairs": pairs,
                "sourceFiles": len(files),
                "rustStatus": rust["serverStatus"],
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--raw", type=Path, default=ROOT / "artifacts/local/architecture-analysis"
    )
    parser.add_argument("--out", type=Path, default=ROOT / "docs/architecture")
    args = parser.parse_args()
    build(ROOT, args.raw, args.out)
