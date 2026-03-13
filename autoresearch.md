# Autoresearch: HTTP/2 request encoding hot paths

## Objective
Optimize Mint's HTTP/2 request-path hot spots with a fast, reproducible benchmark centered on request assembly and frame emission. The initial workload focuses on pure/synthetic HTTP/2 request encoding without real sockets: request header normalization, pseudo-header insertion, default-header insertion, HPACK encoding, HEADERS/CONTINUATION frame generation, and DATA frame splitting.

## Metrics
- **Primary**: `total_us` (µs, lower is better)
- **Secondary**: `basic_request_us`, `body_request_us`, `continuation_request_us`, `checksum`

## How to Run
- Benchmark: `./autoresearch.sh`
- Correctness checks: `./autoresearch.checks.sh`
- The benchmark prints `METRIC name=number` lines.

## Files in Scope
- `lib/mint/http2.ex` — HTTP/2 request path, header processing, HPACK usage, frame splitting, stream bookkeeping.
- `lib/mint/http2/frame.ex` — HTTP/2 frame encode/decode helpers if a bottleneck points there.
- `lib/mint/core/headers.ex` — shared header normalization helpers if they show up in the HTTP/2 path.
- `bench/http2_request_path.exs` — synthetic HTTP/2 request benchmark.
- `autoresearch.sh` — benchmark entrypoint.
- `autoresearch.checks.sh` — focused HTTP/2 correctness checks.
- `autoresearch.md` — experiment context and notes.

## Off Limits
- Public API changes unless there is a clear benchmark win and semantics remain equivalent.
- Dependency changes.
- HTTP/1 code paths unless a truly shared helper is the actual bottleneck.
- Network/proxy/docker infrastructure unrelated to the benchmark.

## Constraints
- Preserve HTTP/2 behavior and public API.
- Focus on measurable primary-metric improvements.
- `test/mint/http2/frame_test.exs` and `test/mint/http2/conn_test.exs` must pass for kept changes.
- Prefer simpler wins over broad complexity.

## What's Been Tried
- Target changed from HTTP/1 to HTTP/2 for this segment; previous HTTP/1 notes are intentionally superseded here.
- Initial HTTP/2 setup uses a synthetic `%Mint.HTTP2{}` connection with a no-op transport so we can benchmark `Mint.HTTP2.request/5` without live sockets.
- The benchmark currently covers three HTTP/2 request workloads:
  - basic GET request encoding with pseudo/default headers
  - POST request encoding with a body large enough to exercise DATA frame splitting
  - GET request encoding with a tiny peer max frame size to force HEADERS/CONTINUATION splitting
- Baseline measurement pending.
