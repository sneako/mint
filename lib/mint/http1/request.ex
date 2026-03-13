defmodule Mint.HTTP1.Request do
  @moduledoc false

  import Mint.HTTP1.Parse

  def encode(method, target, headers, body) do
    body = [
      encode_request_line(method, target),
      encode_headers(headers),
      "\r\n",
      encode_body(body)
    ]

    {:ok, body}
  catch
    {:mint, reason} -> {:error, reason}
  end

  defp encode_request_line(method, target) do
    [method, ?\s, target, " HTTP/1.1\r\n"]
  end

  defp encode_headers(headers) do
    Enum.reduce(headers, "", fn {name, value}, acc ->
      validate_header_name!(name)
      validate_header_value!(name, value)
      [acc, name, ": ", value, "\r\n"]
    end)
  end

  defp encode_body(nil), do: ""
  defp encode_body(:stream), do: ""
  defp encode_body(body), do: body

  def encode_chunk(:eof) do
    "0\r\n\r\n"
  end

  def encode_chunk({:eof, trailing_headers}) do
    ["0\r\n", encode_headers(trailing_headers), "\r\n"]
  end

  def encode_chunk(chunk) do
    length = IO.iodata_length(chunk)
    [Integer.to_string(length, 16), "\r\n", chunk, "\r\n"]
  end

  defp validate_header_name!(name) do
    validate_header_name!(name, name)
  end

  defp validate_header_name!(<<>>, _original_name), do: :ok

  defp validate_header_name!(<<char, rest::binary>>, original_name) when is_tchar(char) do
    validate_header_name!(rest, original_name)
  end

  defp validate_header_name!(_invalid, original_name) do
    throw({:mint, {:invalid_header_name, original_name}})
  end

  defp validate_header_value!(name, value) do
    validate_header_value!(value, name, value)
  end

  defp validate_header_value!(<<>>, _name, _original_value), do: :ok

  defp validate_header_value!(<<char, rest::binary>>, name, original_value)
       when is_vchar(char) or char in ~c"\s\t" do
    validate_header_value!(rest, name, original_value)
  end

  defp validate_header_value!(_invalid, name, original_value) do
    throw({:mint, {:invalid_header_value, name, original_value}})
  end
end
