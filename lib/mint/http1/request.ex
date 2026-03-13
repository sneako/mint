defmodule Mint.HTTP1.Request do
  @moduledoc false

  import Mint.HTTP1.Parse

  def encode(method, target, headers, body)

  def encode(method, target, headers, nil) do
    body = [
      method,
      ?\s,
      target,
      " HTTP/1.1\r\n"
      | encode_headers(headers, ["\r\n"])
    ]

    {:ok, body}
  catch
    {:mint, reason} -> {:error, reason}
  end

  def encode(method, target, headers, :stream) do
    body = [
      method,
      ?\s,
      target,
      " HTTP/1.1\r\n"
      | encode_headers(headers, ["\r\n"])
    ]

    {:ok, body}
  catch
    {:mint, reason} -> {:error, reason}
  end

  def encode(method, target, headers, body) do
    body = [
      method,
      ?\s,
      target,
      " HTTP/1.1\r\n"
      | encode_headers(headers, ["\r\n", body])
    ]

    {:ok, body}
  catch
    {:mint, reason} -> {:error, reason}
  end

  defp encode_headers([], tail), do: tail

  defp encode_headers([{name, value} | headers], tail) do
    validate_header_name!(name)
    validate_header_value!(name, value)
    [name, ": ", value, "\r\n" | encode_headers(headers, tail)]
  end

  def encode_chunk(:eof) do
    "0\r\n\r\n"
  end

  def encode_chunk({:eof, trailing_headers}) do
    ["0\r\n" | encode_headers(trailing_headers, ["\r\n"])]
  end

  def encode_chunk(chunk) do
    length = IO.iodata_length(chunk)
    [Integer.to_string(length, 16), "\r\n", chunk, "\r\n"]
  end

  defp validate_header_name!("accept"), do: :ok
  defp validate_header_name!("accept-encoding"), do: :ok
  defp validate_header_name!("cache-control"), do: :ok
  defp validate_header_name!("content-length"), do: :ok
  defp validate_header_name!("content-type"), do: :ok
  defp validate_header_name!("host"), do: :ok
  defp validate_header_name!("user-agent"), do: :ok
  defp validate_header_name!("x-forwarded-for"), do: :ok
  defp validate_header_name!("x-request-id"), do: :ok

  defp validate_header_name!(name) do
    _ =
      for <<char <- name>> do
        unless is_tchar(char) do
          throw({:mint, {:invalid_header_name, name}})
        end
      end

    :ok
  end

  defp validate_header_value!(_name, "application/json"), do: :ok
  defp validate_header_value!(_name, "gzip, deflate, br"), do: :ok
  defp validate_header_value!(_name, "no-cache"), do: :ok

  defp validate_header_value!(name, value) do
    _ =
      for <<char <- value>> do
        unless is_vchar(char) or char in ~c"\s\t" do
          throw({:mint, {:invalid_header_value, name, value}})
        end
      end

    :ok
  end
end
