#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$PROJECT_DIR"

: "${CAPTURE_URL:?Set CAPTURE_URL to the exact preview URL.}"
: "${CAPTURE_DIR:?Set CAPTURE_DIR to the capture output directory.}"

RUNTIME_DIR="${RUNTIME_DIR:-/home/runner/work/_temp/omgithub-runtime}"
export CAPTURE_URL CAPTURE_DIR

set +e
/usr/bin/time -p node "$RUNTIME_DIR/scripts/default-capture.mjs"
status=$?
set -e

exit "$status"
