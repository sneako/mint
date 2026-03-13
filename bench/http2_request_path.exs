defmodule Bench.NullTransport do
  def send(_socket, _bytes), do: :ok
  def close(_socket), do: :ok
end

defmodule Bench.HTTP2RequestPath do
  alias Mint.HTTP2

  @trials 7
  @basic_iterations 12_000
  @body_iterations 3_000
  @continuation_iterations 2_000

  @basic_headers [
    {"accept", "application/json"},
    {"x-request-id", "req-1234567890abcdef"},
    {"cache-control", "no-cache"}
  ]

  @body_headers [
    {"content-type", "application/json"},
    {"accept", "application/json"},
    {"x-request-id", "req-body-1234567890abcdef"}
  ]

  @body :binary.copy("{\"payload\":\"abcdefghijklmnopqrstuvwxyz0123456789\"}", 160)

  @continuation_headers [
    {"x-long-header-01", :binary.copy("abcdefghij", 8)},
    {"x-long-header-02", :binary.copy("klmnopqrst", 8)},
    {"x-long-header-03", :binary.copy("uvwxyzABCD", 8)},
    {"x-long-header-04", :binary.copy("EFGHIJKLMN", 8)},
    {"x-long-header-05", :binary.copy("OPQRSTUVWX", 8)},
    {"x-long-header-06", :binary.copy("YZ01234567", 8)},
    {"x-long-header-07", :binary.copy("89abcdefgh", 8)},
    {"x-long-header-08", :binary.copy("ijklmnopqr", 8)}
  ]

  def run do
    warmup()

    {basic_us, basic_checksum} = median_trial(&bench_basic_request/0)
    {body_us, body_checksum} = median_trial(&bench_body_request/0)
    {continuation_us, continuation_checksum} = median_trial(&bench_continuation_request/0)

    total_us = basic_us + body_us + continuation_us
    checksum = basic_checksum + body_checksum + continuation_checksum

    IO.puts("METRIC total_us=#{total_us}")
    IO.puts("METRIC basic_request_us=#{basic_us}")
    IO.puts("METRIC body_request_us=#{body_us}")
    IO.puts("METRIC continuation_request_us=#{continuation_us}")
    IO.puts("METRIC checksum=#{checksum}")
  end

  defp warmup do
    bench_basic_request()
    bench_body_request()
    bench_continuation_request()
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

  defp bench_basic_request do
    conn = base_conn()
    {_conn, checksum} = do_basic_request(@basic_iterations, conn, 0)
    checksum
  end

  defp do_basic_request(0, conn, acc), do: {conn, acc}

  defp do_basic_request(left, conn, acc) do
    {:ok, conn, _ref} = HTTP2.request(conn, "GET", "/items?limit=100&offset=200", @basic_headers, nil)
    conn = recycle_conn(conn)
    do_basic_request(left - 1, conn, acc + conn.next_stream_id)
  end

  defp bench_body_request do
    conn = base_conn(max_frame_size: 1024)
    {_conn, checksum} = do_body_request(@body_iterations, conn, 0)
    checksum
  end

  defp do_body_request(0, conn, acc), do: {conn, acc}

  defp do_body_request(left, conn, acc) do
    {:ok, conn, _ref} = HTTP2.request(conn, "POST", "/bulk", @body_headers, @body)
    conn = recycle_conn(conn)
    do_body_request(left - 1, conn, acc + conn.next_stream_id + conn.window_size)
  end

  defp bench_continuation_request do
    conn = base_conn(max_frame_size: 32)
    {_conn, checksum} = do_continuation_request(@continuation_iterations, conn, 0)
    checksum
  end

  defp do_continuation_request(0, conn, acc), do: {conn, acc}

  defp do_continuation_request(left, conn, acc) do
    {:ok, conn, _ref} = HTTP2.request(conn, "GET", "/continuation", @continuation_headers, nil)
    conn = recycle_conn(conn)
    do_continuation_request(left - 1, conn, acc + conn.next_stream_id)
  end

  defp recycle_conn(conn) do
    %{
      conn
      | streams: %{},
        ref_to_stream_id: %{},
        open_client_stream_count: 0,
        window_size: 65_535
    }
  end

  defp base_conn(opts \\ []) do
    max_frame_size = Keyword.get(opts, :max_frame_size, 16_384)

    server_settings = %{
      enable_push: true,
      max_concurrent_streams: 1_000_000,
      initial_window_size: 65_535,
      max_frame_size: max_frame_size,
      max_header_list_size: :infinity,
      enable_connect_protocol: false
    }

    struct(HTTP2,
      transport: Bench.NullTransport,
      socket: :bench,
      mode: :active,
      hostname: "example.com",
      port: 443,
      scheme: "https",
      authority: "example.com",
      state: :open,
      server_settings: server_settings,
      encode_table: HPAX.new(4096),
      decode_table: HPAX.new(4096)
    )
  end
end

Bench.HTTP2RequestPath.run()
