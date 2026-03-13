defmodule Mint.HTTP1.Response do
  @moduledoc false

  alias Mint.Core.Headers

  def decode_status_line(binary) do
    case :erlang.decode_packet(:http_bin, binary, []) do
      {:ok, {:http_response, version, status, reason}, rest} ->
        {:ok, {version, status, reason}, rest}

      {:ok, _other, _rest} ->
        :error

      {:more, _length} ->
        :more

      {:error, _reason} ->
        :error
    end
  end

  def decode_header(binary) do
    case :erlang.decode_packet(:httph_bin, binary, []) do
      {:ok, {:http_header, _unused, :Connection, _reserved, value}, rest} ->
        {:ok, {"connection", value}, rest}

      {:ok, {:http_header, _unused, :Date, _reserved, value}, rest} ->
        {:ok, {"date", value}, rest}

      {:ok, {:http_header, _unused, :Etag, _reserved, value}, rest} ->
        {:ok, {"etag", value}, rest}

      {:ok, {:http_header, _unused, :Server, _reserved, value}, rest} ->
        {:ok, {"server", value}, rest}

      {:ok, {:http_header, _unused, :"Content-Length", _reserved, value}, rest} ->
        {:ok, {"content-length", value}, rest}

      {:ok, {:http_header, _unused, :"Content-Type", _reserved, value}, rest} ->
        {:ok, {"content-type", value}, rest}

      {:ok, {:http_header, _unused, :"Transfer-Encoding", _reserved, value}, rest} ->
        {:ok, {"transfer-encoding", value}, rest}

      {:ok, {:http_header, _unused, name, _reserved, value}, rest} ->
        {:ok, {header_name(name), value}, rest}

      {:ok, :http_eoh, rest} ->
        {:ok, :eof, rest}

      {:ok, _other, _rest} ->
        :error

      {:more, _length} ->
        :more

      {:error, _reason} ->
        :error
    end
  end

  defp header_name(:Connection), do: "connection"
  defp header_name(:Date), do: "date"
  defp header_name(:Etag), do: "etag"
  defp header_name(:Server), do: "server"
  defp header_name(:"Content-Length"), do: "content-length"
  defp header_name(:"Content-Type"), do: "content-type"
  defp header_name(:"Transfer-Encoding"), do: "transfer-encoding"
  defp header_name(atom) when is_atom(atom), do: atom |> Atom.to_string() |> header_name()
  defp header_name(binary) when is_binary(binary), do: Headers.lower_raw(binary)
end
