#!/usr/bin/env bash
set -euo pipefail

MIX_ENV=dev mix compile --warnings-as-errors >/dev/null
MIX_ENV=dev mix run --no-start --no-compile bench/http2_request_path.exs
