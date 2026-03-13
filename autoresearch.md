# Autoresearch: HTTP/1 hot paths

## Objective
Optimize Mint's HTTP/1 request encoding and response-header parsing hot paths with a fast, reproducible microbenchmark. The initial workload focuses on code that runs for every HTTP/1 request/response cycle without requiring live sockets: request assembly (`Mint.HTTP1.Request.encode/4`) and response header parsing/normalization (`Mint.HTTP1.Response.decode_header/1` plus `Mint.HTTP1.Parse` header-value parsing helpers).

## Metrics
- **Primary**: `total_us` (µs, lower is better)
- **Secondary**: `request_encode_us`, `response_header_flow_us`, `checksum`

## How to Run
- Benchmark: `./autoresearch.sh`
- Correctness checks: `./autoresearch.checks.sh`
- The benchmark prints `METRIC name=number` lines.

## Files in Scope
- `lib/mint/http1/request.ex` — HTTP/1 request encoding and header validation.
- `lib/mint/http1/parse.ex` — parsing helpers for HTTP/1 header values.
- `lib/mint/http1/response.ex` — header decoding and name normalization bridge.
- `lib/mint/core/headers.ex` — lowercasing/raw header normalization helpers.
- `lib/mint/http1.ex` — integration layer for HTTP/1 header/body decode flow if needed.
- `bench/http1_hot_paths.exs` — benchmark workload definition.
- `autoresearch.sh` — benchmark entrypoint.
- `autoresearch.checks.sh` — focused correctness checks.
- `autoresearch.md` — experiment context and notes.

## Off Limits
- Public API changes unless required for a clear benchmark win.
- Dependency changes.
- HTTP/2 code paths unless a shared helper in scope is the actual bottleneck.
- Proxy/docker/integration infrastructure unrelated to the benchmark.

## Constraints
- Keep behavior and public API unchanged.
- Focus on measurable improvements to the primary metric.
- Focused HTTP/1 tests in `autoresearch.checks.sh` must pass for kept changes.
- Avoid adding complexity unless the gain is clear and repeatable.

## What's Been Tried
- Initial setup created a benchmark around two reproducible micro-workloads:
  - repeated `Mint.HTTP1.Request.encode/4` on a realistic POST request
  - repeated response-header decode flow covering `Response.decode_header/1`, `Parse.content_length_header/1`, `Parse.connection_header/1`, and `Parse.transfer_encoding_header/1`
- Focused checks: `test/mint/http1/parse_test.exs`, `test/mint/http1/request_test.exs`, and `test/mint/http1/conn_test.exs`.
- Baseline after setup: `total_us=99635`.
- **Kept:** cache lowercase strings for common atom header names in `Mint.HTTP1.Response.header_name/1`. This was the biggest response-path win so far.
- **Kept:** build connection/transfer-encoding tokens via byte lists instead of repeated binary appends in `Mint.HTTP1.Parse`.
- **Kept:** replace nested/reversed request-header builders with direct recursive iodata construction in `Mint.HTTP1.Request.encode_headers/1`.
- **Discarded:** recursive byte-by-byte request header validators regressed the request path noticeably.
- **Discarded:** manual ASCII `content-length` parsing was slower than `String.trim_trailing/1` + `Integer.parse/1` on this workload.
- **Discarded:** custom ASCII downcasing in `Mint.Core.Headers.lower_raw/1` was slower than `String.downcase(..., :ascii)`.
- Current best after the kept changes above: `total_us=71327`.
