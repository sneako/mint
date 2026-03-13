#!/usr/bin/env bash
set -euo pipefail

log_file=$(mktemp)
trap 'rm -f "$log_file"' EXIT

if ! MIX_ENV=test mix test \
  test/mint/http2/frame_test.exs \
  test/mint/http2/conn_test.exs \
  --color never --max-failures 1 >"$log_file" 2>&1; then
  tail -n 80 "$log_file"
  exit 1
fi
