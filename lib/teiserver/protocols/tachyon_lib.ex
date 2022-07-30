defmodule Teiserver.Protocols.TachyonLib do
  require Logger

  @spec get_modules :: {module(), module()}
  def get_modules(), do: get_modules("v1")

  @spec get_modules(String.t()) :: {module(), module()}
  def get_modules("dev") do
    {Teiserver.Protocols.Tachyon.V1.TachyonIn, Teiserver.Protocols.Tachyon.V1.TachyonOut}
  end

  def get_modules("v1") do
    {Teiserver.Protocols.Tachyon.V1.TachyonIn, Teiserver.Protocols.Tachyon.V1.TachyonOut}
  end

  @spec format_log(String.t()) :: String.t()
  def format_log(s) do
    Kernel.inspect(s)
  end

  @spec encode(List.t() | Map.t()) :: String.t()
  def encode(data) do
    case Jason.encode(data) do
      {:ok, encoded_data} ->
        encoded_data
          |> :zlib.gzip()
          |> Base.encode64()
      {:error, err} ->
        Logger.error("Tachyon encode error: #{Kernel.inspect err}\ndata: #{Kernel.inspect data}")

        %{
          result: "s.system.server_protocol_error",
          error: "JSON encode"
        }
        ""
          |> Jason.encode!
          |> :zlib.gzip()
          |> Base.encode64()
    end



  end

  @spec decode(String.t() | :timeout) :: {:ok, List.t() | Map.t()} | {:error, :bad_json}
  def decode(:timeout), do: {:ok, nil}
  def decode(""), do: {:ok, nil}
  def decode(data) do
    with {:ok, decoded64} <- Base.decode64(data |> String.trim),
         {:ok, unzipped} <- unzip(decoded64),
         {:ok, object} <- Jason.decode(unzipped) do
      {:ok, object}
    else
      :error ->
        # Previously got an error with data 'OK cmd=TACHYON' which suggests
        # it was still in Spring mode
        Logger.warn("Base64 error, given '#{data}'")
        {:error, :base64_decode}
      {:error, :gzip_decompress} ->
        Logger.warn("Gzip error, given '#{data}'")
        {:error, :gzip_decompress}
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

  @spec decode!(String.t() | :timeout) :: List.t() | Map.t()
  def decode!(data) do
    case decode(data) do
      {:ok, result} -> result
      {:error, reason} ->
        raise "Tachyon decode! error: #{reason}, data: #{data}"
    end
  end


  @spec query(List.t(), atom | nil, any) :: List.t()
  def query(list, nil, _), do: list
  def query(list, _, nil), do: list
  def query(list, field, value) when is_atom(field) do
    list
    |> Enum.filter(fn item -> Map.get(item, field) == value end)
  end

  @spec query_in(List.t(), atom | nil, List.t()) :: List.t()
  def query_in(list, nil, _), do: list
  def query_in(list, _, nil), do: list
  def query_in(list, field, value) when is_atom(field) do
    list
    |> Enum.filter(fn item -> Enum.member?(value, Map.get(item, field)) end)
  end

  # def query(list, _, func) when is_function(func) do
  #   list
  #   |> Enum.filter(fn item ->
  #     func.(item)
  #   end)
  # end
end
