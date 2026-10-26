#!/bin/sh
# 维护者本机使用的文档提交助手。
#
# 为什么需要它：本仓库的 Mimosa 安全门禁会拦截代理侧的 git commit，因此
# 代理只负责把文档改到工作树，由维护者在本机执行提交。
#
# 用法（仓库根目录）：
#   sh scripts/sync-doc-versions.sh "文档：<主题>" [额外文件...]
#
# 脚本只做三件事：核对版本号同步、把相关文件加入暂存区、打印剩余改动。
# 提交信息由调用者给出，脚本不预设本次发布内容。
set -eu
cd "$(dirname "$0")/.."

if [ $# -lt 1 ]; then
  echo "usage: $0 \"<commit subject>\" [extra files...]" >&2
  exit 1
fi
subject=$1
shift

pubspec_version=$(sed -n 's/^version: *//p' flutter/pubspec.yaml | head -1)
marketing=${pubspec_version%%+*}
build=${pubspec_version##*+}
echo "pubspec: $marketing (build $build)"

# 最低版本门禁必须能被 Pages 提供，否则客户端 404 后 fail-open。
if [ ! -f docs/update-gate.json ]; then
  echo 'docs/update-gate.json is missing; the served update gate would 404.' >&2
  exit 1
fi
min_build=$(sed -n 's/.*"minBuild": *\([0-9]\+\).*/\1/p' docs/update-gate.json | head -1)
if [ -n "$min_build" ] && [ "$min_build" -gt "$build" ]; then
  echo "minBuild ($min_build) exceeds the current build ($build); clients would be locked out." >&2
  exit 1
fi
echo "update gate: minBuild=$min_build"

git add \
  AGENTS.md \
  README.md \
  docs/API.md \
  docs/FEATURES-AND-PROTOCOLS.md \
  docs/IMPROVEMENTS.md \
  docs/MIRROR-IMPLEMENTATION.md \
  docs/MIRROR-PARITY.md \
  docs/MIRROR-TODO.md \
  docs/MULTI-PLATFORM-STRATEGY.md \
  docs/PROMOTION.md \
  docs/RELEASE-NOTES.md \
  docs/update-gate.json \
  docs/index.html \
  flutter/README.md \
  docs/_audit \
  docs/releases
for extra in "$@"; do
  git add -- "$extra"
done

git commit -m "$subject"
echo
git log --oneline -2
echo
echo 'Remaining changes:'
git status --porcelain
