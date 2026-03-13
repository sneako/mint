defmodule Bench.HTTP1HotPaths do
  alias Mint.HTTP1.{Parse, Request, Response}

  @trials 7
  @request_iterations 60_000
  @response_iterations 25_000

  @request_headers [
    {"host", "example.com"},
    {"user-agent", "mint-autoresearch/1.0"},
    {"accept", "application/json"},
    {"accept-encoding", "gzip, deflate, br"},
    {"content-type", "application/json"},
    {"content-length", "128"},
    {"x-request-id", "req-1234567890abcdef"},
    {"x-forwarded-for", "127.0.0.1"},
    {"cache-control", "no-cache"}
  ]

  @request_body ~S({"hello":"world","numbers":[1,2,3,4],"flags":{"fast":true,"trace":false},"payload":"abcdefghijklmnopqrstuvwxyz"})

  @response_headers [
    "Content-Length: 1234\r\n\r\n",
    "Connection: Keep-Alive, Upgrade\r\n\r\n",
    "Transfer-Encoding: gzip, Chunked\r\n\r\n",
    "Date: Tue, 11 Mar 2025 10:00:00 GMT\r\n\r\n",
    "Content-Type: application/json; charset=utf-8\r\n\r\n",
    "ETag: \"abc123etag\"\r\n\r\n",
    "X-Trace-Id: TRACE-abcdef123456\r\n\r\n",
    "Server: mint-test\r\n\r\n"
  ]

  def run do
    warmup()

    {request_us, request_checksum} = median_trial(&bench_request_encode/0)
    {response_us, response_checksum} = median_trial(&bench_response_header_flow/0)

    total_us = request_us + response_us
    checksum = request_checksum + response_checksum

    IO.puts("METRIC total_us=#{total_us}")
    IO.puts("METRIC request_encode_us=#{request_us}")
    IO.puts("METRIC response_header_flow_us=#{response_us}")
    IO.puts("METRIC checksum=#{checksum}")
  end

  defp warmup do
    bench_request_encode()
    bench_response_header_flow()
  end

  defp median_trial(fun) do
    1..@trials
    |> Enum.map(fn _ -> timed(fun) end)
    |> Enum.sort_by(fn {elapsed_us, _checksum} -> elapsed_us end)
    |> Enum.at(div(@trials, 2))
  end

  defp timed(fun) do
    start = System.monotonic_time()
    checksum = fun.()
    elapsed = System.monotonic_time() - start
    {System.convert_time_unit(elapsed, :native, :microsecond), checksum}
  end

  defp bench_request_encode do
    do_request_encode(@request_iterations, 0)
  end

  defp do_request_encode(0, acc), do: acc

  defp do_request_encode(left, acc) do
    {:ok, iodata} =
      Request.encode(
        "POST",
        "/v1/resources?limit=100&offset=200&sort=inserted_at",
        @request_headers,
        @request_body
      )

    do_request_encode(left - 1, acc + IO.iodata_length(iodata))
  end

  defp bench_response_header_flow do
    do_response_header_flow(@response_iterations, 0)
  end

  defp do_response_header_flow(0, acc), do: acc

  defp do_response_header_flow(left, acc) do
    acc = Enum.reduce(@response_headers, acc, &decode_header_line/2)
    do_response_header_flow(left - 1, acc)
  end

  defp decode_header_line(line, acc) do
    {:ok, {name, value}, _rest} = Response.decode_header(line)

    acc = acc + byte_size(name) + byte_size(value)

    case name do
      "content-length" ->
        {:ok, length} = Parse.content_length_header(value)
        acc + length

      "connection" ->
        {:ok, tokens} = Parse.connection_header(value)
        acc + sum_token_sizes(tokens)

      "transfer-encoding" ->
        {:ok, tokens} = Parse.transfer_encoding_header(value)
        acc + sum_token_sizes(tokens)

      _other ->
        acc
    end
  end

  defp sum_token_sizes(tokens) do
    Enum.reduce(tokens, 0, fn token, acc -> acc + byte_size(token) end)
  end
end

Bench.HTTP1HotPaths.run()
