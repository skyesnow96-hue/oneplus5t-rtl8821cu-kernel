#!/usr/bin/env bash
# Top-level wrapper around the zero-kernel builder. Assumes zero-kernel-v0.6.4
# is already checked out as a sibling directory and the driver patch was applied.
set -euo pipefail
DIR="$(cd "${0%/*}" && pwd)"
cd "${DIR}/../zero-kernel-v0.6.4"
docker build . -f Dockerfile -t zero-kernel-image --load
uv run --python 3.12 zkb kernel --build-env=docker --base=los --codename=dumpling --lkv=4.4
echo "Build done. ZIP in kernel/zero-0.6.4-dumplinger-los-4.4.zip"
