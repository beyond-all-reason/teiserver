defmodule Teiserver.Protocols.Tachyon do
  require Logger
  alias Teiserver.Client
  alias Teiserver.Battle.Lobby
  alias Phoenix.PubSub
  alias Teiserver.Protocols.TachyonIn
  alias Teiserver.Protocols.TachyonOut

  def format_log(s) do
    Kernel.inspect(s)
  end

  def reply(namespace, reply_cmd, data, state),
    do: TachyonOut.reply(namespace, reply_cmd, data, state)
  def reply(namespace, reply_cmd, data, _msg_id, state),
    do: TachyonOut.reply(namespace, reply_cmd, data, state)

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
  @spec convert_object(:user | :user_extended | :client | :battle | :queue | :blog_post, Map.t() | nil) :: Map.t() | nil
  def convert_object(_, nil), do: nil
  def convert_object(:user, user), do: Map.take(user, [:id, :name, :bot, :clan_id, :skill, :icons, :springid])
  def convert_object(:user_extended, user), do: Map.take(user, [:id, :name, :bot, :clan_id, :skill, :icons, :permissions,
                    :friends, :friend_requests, :ignores, :springid])
  def convert_object(:client, client), do: Map.take(client, [:id, :in_game, :away, :ready, :team_number, :ally_team_number,
                    :team_colour, :role, :bonus, :synced, :faction, :lobby_id])
  def convert_object(:lobby, lobby), do: Map.take(lobby, [:id, :name, :founder_id, :type, :max_players, :password,
                    :locked, :engine_name, :engine_version, :players, :spectators, :bots, :ip, :settings, :map_name,
                    :map_hash])
  def convert_object(:queue, queue), do: Map.take(queue, [:id, :name, :team_size, :conditions, :settings, :map_list])
  def convert_object(:blog_post, post), do: Map.take(post, ~w(id short_content content url tags live_from)a)

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
    with {:ok, decoded64} <- Base.decode64(data |> String.trim),
         {:ok, unzipped} <- unzip(decoded64),
         {:ok, object} <- Jason.decode(unzipped) do
      {:ok, object}
    else
      :error -> {:error, :base64_decode}
      {:error, :gzip_decompress} -> {:error, :gzip_decompress}
      {:error, %Jason.DecodeError{}} -> {:error, :bad_json}
    end
  end

  @spec decode!(String.t() | :timeout) :: List.t() | Map.t()
  def decode!(data) do
    case decode(data) do
      {:ok, result} -> result
      {:error, reason} ->
        throw "Tachyon decode! error: #{reason}, data: #{data}"
    end
  end

  @spec do_login_accepted(Map.t(), Map.t()) :: Map.t()
  def do_login_accepted(state, user) do
    # Login the client
    Client.login(user, self())

    send(self(), {:action, {:login_end, nil}})
    PubSub.unsubscribe(Central.PubSub, "legacy_user_updates:#{user.id}")
    :ok = PubSub.subscribe(Central.PubSub, "legacy_user_updates:#{user.id}")
    %{state | user: user, username: user.name, userid: user.id}
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

  def do_leave_battle(state, lobby_id) do
    PubSub.unsubscribe(Central.PubSub, "legacy_battle_updates:#{lobby_id}")
    state
  end

  # Does the joining of a battle
  @spec do_join_battle(map(), integer(), String.t()) :: map()
  def do_join_battle(state, lobby_id, script_password) do
    # TODO: Change this function to be purely about sending info to the client
    # the part where it calls Lobby.add_user_to_battle should happen elsewhere
    battle = Lobby.get_battle(lobby_id)
    Lobby.add_user_to_battle(state.userid, battle.id, script_password)
    PubSub.unsubscribe(Central.PubSub, "legacy_battle_updates:#{battle.id}")
    PubSub.subscribe(Central.PubSub, "legacy_battle_updates:#{battle.id}")
    TachyonOut.reply(:lobby, :join_response, {:approve, battle}, state)

    TachyonOut.reply(:lobby, :request_status, nil, state)

    %{state | lobby_id: battle.id}
  end
end
