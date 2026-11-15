#!/bin/bash
# Apply the small portability patches required by the iOS 6 SDK/toolchain.
# Safe to run repeatedly: already-applied patches are detected and skipped.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

for p in "$ROOT"/deps/patches/*.patch; do
  echo "==> $(basename "$p")"
  if git apply --check -p1 --directory=deps/src --whitespace=nowarn "$p" 2>/dev/null; then
    git apply -p1 --directory=deps/src --whitespace=nowarn "$p"
  elif git apply --check -R -p1 --directory=deps/src --whitespace=nowarn "$p" 2>/dev/null; then
    echo "    already applied"
  else
    echo "Failed to apply $p" >&2
    exit 1
  fi
done
