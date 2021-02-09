defmodule Teiserver.Client do
  alias Phoenix.PubSub
  alias Teiserver.Battle
  alias Teiserver.BitParse

  def create(client) do
    Map.merge(%{
      in_game: false,
      status: "0",
      away: false,
      rank: 1,
      moderator: 0,
      bot: 0,
      battlestatus: 0,
      team_colour: 0,
      battle_id: nil
    }, client)
  end

  def create(name, pid, protocol) do
    %{
      pid: pid,
      name: name,
      protocol: protocol,
      status: "0",
      in_game: false,
      away: false,
      rank: 1,
      moderator: 0,
      bot: 0,
      battlestatus: 0,
      team_colour: 0,
      battle_id: nil
    }
  end

  # def create_from_user(user, client) do
  #   Map.merge(client, %{
  #     rank: user.rank,
  #     moderator: (user.moderator == 1),
  #     bot: (user.bot == 1)
  #   })
  # end

  # def create_from_bits([0], client) do
  #   Map.merge(client, %{
  #     in_game: 0,
  #     away: 0
  #   })
  # end

  def login(user, pid, protocol) do
    client = create(%{
      name: user.name,
      pid: pid,
      protocol: protocol,
      rank: user.rank,
      moderator: user.moderator,
      bot: user.bot,
      away: false,
      in_game: false
    })
    |> calculate_status
    |> add_client

    PubSub.broadcast Teiserver.PubSub, "client_updates", {:logged_in_client, user.name}
    client
  end

  def calculate_status(client) do
    [r1, r2, r3] = BitParse.parse_bits("#{client.rank}", 3)

    status = [
      (if client.in_game, do: 1, else: 0),
      (if client.away, do: 1, else: 0),
      r1,
      r2,
      r3,
      (if client.moderator, do: 1, else: 0),
      (if client.bot, do: 1, else: 0)
    ]
    |> Integer.undigits(2)
    %{client | status: status}
  end

  def update(client, reason \\ nil) do
    client = calculate_status(client)
    add_client(client)
    PubSub.broadcast Teiserver.PubSub, "client_updates", {:updated_client, client, reason}
    client
  end

  def new_battlestatus(username, new_battlestatus, team_colour) do
    :ok = PubSub.broadcast Teiserver.PubSub, "client_updates", {:new_battlestatus, username, new_battlestatus, team_colour}
    client = get_client(username)
    Map.merge(client, %{
      battlestatus: new_battlestatus,
      team_colour: team_colour,
    })
    |> add_client
  end

  def leave_battle(username) do
    :ok = PubSub.broadcast Teiserver.PubSub, "client_updates", {:new_battlestatus, username, 0, 0}
    client = get_client(username)
    new_client = Map.merge(client, %{
      battlestatus: 0,
      team_colour: 0,
      battle_id: nil
    })
    |> add_client

    Battle.remove_user_from_battle(username, client.battle_id)
    new_client
  end

  def get_client(username) do
    ConCache.get(:clients, username)
  end

  def add_client(client) do
    ConCache.put(:clients, client.name, client)
    ConCache.update(:lists, :clients, fn value ->
      new_value = (value ++ [client.name])
      |> Enum.uniq

      {:ok, new_value}
    end)
    client
  end

  def list_client_names() do
    ConCache.get(:lists, :clients)
  end

  def list_clients() do
    ConCache.get(:lists, :clients)
    |> Enum.map(fn username -> ConCache.get(:clients, username) end)
  end

  def get_client_state(pid) do
    GenServer.call(pid, :get_state)
  end

  def disconnect(name) do
    ConCache.delete(:clients, name)
    ConCache.update(:lists, :clients, fn value -> 
      new_value = value
      |> Enum.filter(fn v -> v != name end)

      {:ok, new_value}
    end)
  end
end