defmodule Teiserver.Protocols.Tachyon do
  require Logger
  alias Teiserver.Client
  alias Teiserver.Battle
  alias Phoenix.PubSub
  alias Teiserver.Protocols.TachyonIn
  alias Teiserver.Protocols.TachyonOut

  def format_log(s) do
    Kernel.inspect(s)
  end

  def reply(namespace, reply_cmd, data, state), do: TachyonOut.reply(namespace, reply_cmd, data, state)

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
    :ok = PubSub.subscribe(Central.PubSub, "user_updates:#{user.id}")
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


  # Does the joining of a battle
  @spec do_join_battle(map(), integer(), String.t()) :: map()
  def do_join_battle(state, battle_id, script_password) do
    # TODO: Change this function to be purely about sending info to the client
    # the part where it calls Battle.add_user_to_battle should happen elsewhere
    battle = Battle.get_battle(battle_id)
    Battle.add_user_to_battle(state.userid, battle.id, script_password)
    PubSub.subscribe(Central.PubSub, "battle_updates:#{battle.id}")
    TachyonOut.reply(:battle, :join_response, {:approve, battle}, state)

    # [battle.founder_id | battle.players]
    # |> Enum.each(fn id ->
    #   client = Client.get_client_by_id(id)
    #   TachyonOut.reply(:client_battlestatus, client, nil, state)
    # end)

    # battle.bots
    # |> Enum.each(fn {_botname, bot} ->
    #   TachyonOut.reply(:add_bot_to_battle, {battle.id, bot}, nil, state)
    # end)

    # client = Client.get_client_by_id(state.userid)
    # TachyonOut.reply(:client_battlestatus, client, nil, state)

    # battle.start_rectangles
    # |> Enum.each(fn {team, r} ->
    #   TachyonOut.reply(:add_start_rectangle, {team, r}, nil, state)
    # end)

    # TachyonOut.reply(:request_battle_status, nil, nil, state)

    %{state | battle_id: battle.id}
  end
end
