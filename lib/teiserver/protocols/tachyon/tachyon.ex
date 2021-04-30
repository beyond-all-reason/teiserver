defmodule Teiserver.Protocols.Tachyon do
  require Logger
  alias Teiserver.Protocols.TachyonIn

  def format_log(s) do
    Kernel.inspect(s)
  end

  @spec data_in(String.t(), Map.t()) :: Map.t()
  def data_in(data, state) do
    if state.extra_logging do
      Logger.info(
        "<-- #{state.username}: #{format_log(data)}"
      )
    end

    new_state =
      if String.ends_with?(data, "\n") do
        data = state.message_part <> data

        data
        |> String.split("\n")
        |> Enum.reduce(state, fn data, acc ->
          TachyonIn.handle(data, acc)
        end)
        |> Map.put(:message_part, "")
      else
        %{state | message_part: state.message_part <> data}
      end

    new_state
  end

  @spec encode(List.t() | Map.t()) :: String.t()
  def encode(data) do
    data
    |> Jason.encode!
    |> :zlib.gzip
    |> Base.encode64()
  end

  @spec decode(String.t()) :: {:ok, List.t() | Map.t()} | {:error, :bad_json}
  def decode(data) do
    with {:ok, decoded64} <- Base.decode64(data),
         {:ok, unzipped} <- unzip(decoded64),
         {:ok, object} <- Jason.decode(unzipped)
    do
      {:ok, object}
    else
      :error -> {:error, :base64_decode}
      {:error, :gzip_decompress} -> {:error, :gzip_decompress}
      {:error, %Jason.DecodeError{}} -> {:error, :bad_json}
    end
  end

  defp unzip(data) do
    try do
      result = :zlib.gunzip(data)
      {:ok, result}
    rescue
      _ ->
        {:error, :gzip_decompress}
    end
  end
end
