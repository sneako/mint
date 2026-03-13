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
- **Kept:** cache lowercase strings for common atom header names in `Mint.HTTP1.Response.header_name/1`.
- **Kept:** build connection/transfer-encoding tokens via byte lists instead of repeated binary appends in `Mint.HTTP1.Parse`.
- **Kept:** replace nested/reversed request-header builders with direct recursive iodata construction in `Mint.HTTP1.Request.encode_headers/1`.
- **Kept:** inline the common atom-header mappings directly in `Mint.HTTP1.Response.decode_header/1`; this beat routing through `header_name/1` after `decode_packet/3`.
- **Kept:** add exact-match fast paths for very common `connection` / `transfer-encoding` values (`close`, `Keep-Alive`, `Keep-Alive, Upgrade`, `chunked`, `gzip, Chunked`) before generic token parsing.
- **Kept:** add exact-name validation fast paths for common request headers (`accept`, `accept-encoding`, `cache-control`, `content-length`, `content-type`, `host`, `user-agent`, `x-forwarded-for`, `x-request-id`) before falling back to generic bytewise validation.
- **Kept:** add exact-value validation fast paths for a few common generic header values (`application/json`, `gzip, deflate, br`, `no-cache`).
- **Kept:** flatten `Request.encode/4` and trailing-header encoding into one threaded iodata chain instead of stitching together nested helper results.
- **Kept:** specialize `Request.encode/4` for `nil` and `:stream` bodies on top of the flattened builder.
- **Kept:** specialize `encode_headers/2` for common request header names so they skip separate name-validation dispatch.
- **Discarded:** recursive byte-by-byte request header validators regressed the request path noticeably.
- **Discarded:** manual ASCII `content-length` parsing was slower than `String.trim_trailing/1` + `Integer.parse/1` on this workload.
- **Discarded:** custom ASCII downcasing in `Mint.Core.Headers.lower_raw/1` was slower than `String.downcase(..., :ascii)`.
- **Discarded:** direct `X-Trace-Id` binary-name fast path in `Response.decode_header/1` was slightly worse than the generic fallback.
- **Discarded:** specializing `Request.encode/4` for `nil` / `:stream` bodies regressed.
- **Discarded:** direct pair-specialization in `encode_headers/1` regressed versus the cheaper exact-name/value validator fast paths.
- **Discarded:** re-testing pair-specialization inside the newer specialized encoder still regressed.
- **Discarded:** moving generic validators to `for ... reduce:` scans regressed badly.
- **Discarded:** validating outbound `content-length` with `Integer.parse/1` was slower than the generic visible-ASCII validator.
- **Discarded:** a `header_name/1` binary fast path for `X-Trace-Id` was still slightly worse.
- **Discarded / checks failed:** a manual exact-prefix parser for common response headers both regressed badly and broke `101 Switching Protocols` trailing-data handling by leaving an extra `\r\n` in the remainder.
- **Discarded:** persistent-term cached compiled invalid-byte patterns plus `:binary.match/2` were much slower than the existing validation approach.
- Current best: `total_us=48572`.
