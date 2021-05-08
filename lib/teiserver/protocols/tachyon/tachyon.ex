defmodule Teiserver.Protocols.Tachyon do
  require Logger
  alias Teiserver.Protocols.TachyonIn

  def format_log(s) do
    Kernel.inspect(s)
  end

  @spec data_in(String.t(), Map.t()) :: Map.t()
  def data_in(data, state) do
    if state.extra_logging do
      Logger.info("<-- #{state.username}: #{format_log(data)}")
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

  @doc """
  Used to convert objects into something that will be sent back over the wire. We use this
  as there might be internal fields we don't want sent out (e.g. email).
  """
  @spec convert_object(:user | :user_extended | :client | :battle | :queue, Map.t()) :: Map.t()
  def convert_object(:user, user), do: Map.take(user, [:id, :name, :bot, :clan_id, :skill, :icons])
  def convert_object(:user_extended, user), do: Map.take(user, [:id, :name, :bot, :clan_id, :skill, :icons, :permissions,
                    :friends, :friend_requests, :ignores])
  def convert_object(:client, client), do: Map.take(client, [:id, :in_game, :away, :ready, :team_number, :ally_team_number,
                    :team_colour, :role, :bonus, :synced, :faction, :battle_id])
  def convert_object(:battle, battle), do: Map.take(battle, [:id, :name, :founder_id, :type, :max_players, :password,
                    :locked, :engine_name, :engine_version, :players, :spectators, :bots, :ip, :settings, :map_name,
                    :map_hash])
  def convert_object(:queue, queue), do: Map.take(queue, [:id, :name, :team_size, :conditions, :settings, :map_list])

  @spec encode(List.t() | Map.t()) :: String.t()
  def encode(data) do
    data
    |> Jason.encode!()
    |> :zlib.gzip()
    |> Base.encode64()
  end

  @spec decode(String.t() | :timeout) :: {:ok, List.t() | Map.t()} | {:error, :bad_json}
  def decode(:timeout), do: {:ok, nil}
  def decode(data) do
    with {:ok, decoded64} <- Base.decode64(data),
         {:ok, unzipped} <- unzip(decoded64),
         {:ok, object} <- Jason.decode(unzipped) do
      {:ok, object}
    else
      :error -> {:error, :base64_decode}
      {:error, :gzip_decompress} -> {:error, :gzip_decompress}
      {:error, %Jason.DecodeError{}} -> {:error, :bad_json}
    end
  end

  @spec decode!(String.t() | :timeout) :: {:ok, List.t() | Map.t()} | {:error, :bad_json}
  def decode!(data) do
    case decode(data) do
      {:ok, result} -> result
      {:error, reason} -> throw "Tachyon decode! error - #{reason}"
    end
  end

  @spec do_login_accepted(Map.t(), Map.t()) :: Map.t()
  def do_login_accepted(state, _user) do
    state
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
