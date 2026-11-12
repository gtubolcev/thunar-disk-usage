#!/usr/bin/env bash
# Copy the plugin source (the repo without the packaging, CI and private files)
# to <dir>, for build-deb.sh, build-arch.sh and upload-ppa.sh.
#
#   scripts/source.sh <dir>
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$1"
tar -C "$ROOT" --exclude=./.git --exclude=./.github --exclude=./scripts \
  --exclude=./docs --exclude=./arch --exclude=./PLAN.md --exclude=./_build \
  --exclude=./out --exclude=./_tmp -cf - . | tar -C "$1" -xf -
