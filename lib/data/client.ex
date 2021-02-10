defmodule Teiserver.Client do
  alias Phoenix.PubSub
  alias Teiserver.Battle
  alias Teiserver.BitParse

  def create(client) do
    Map.merge(%{
      status: "0",
      in_game: false,
      away: false,
      rank: 1,
      moderator: 0,
      bot: 0,
      
      # Battle stuff
      ready: false,
      team_number: 0,
      ally_team_number: 0,
      spectator: true,
      handicap: 0,
      sync: 0,
      side: 0,

      battlestatus: 0,
      team_colour: 0,
      battle_id: nil
    }, client)
  end

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

  def calculate_battlestatus(client) do
    [t1, t2, t3, t4] = BitParse.parse_bits("#{client.team_number}", 4)
    [a1, a2, a3, a4] = BitParse.parse_bits("#{client.ally_team_number}", 4)
    [h1, h2, h3, h4, h5, h6, h7] = BitParse.parse_bits("#{client.handicap}", 7)
    [sync1, sync2] = BitParse.parse_bits("#{client.sync}", 2)
    [side1, side2, side3, side4] = BitParse.parse_bits("#{client.side}", 4)
    
    battlestatus = [0, (if client.ready, do: 1, else: 0),
    t1, t2, t3, t4,
    a1, a2, a3, a4,
    (if client.spectator, do: 1, else: 0),
    h1, h2, h3, h4, h5, h6, h7,
    0, 0, 0, 0,
    sync1, sync2,
    side1, side2, side3, side4,
    0, 0, 0, 0]
    |> Integer.undigits(2)
    %{client | battlestatus: battlestatus}
  end

  def update(client, reason \\ nil) do
    client = client
    |> calculate_status
    |> calculate_battlestatus
    |> add_client
    PubSub.broadcast Teiserver.PubSub, "client_updates", {:updated_client, client, reason}
    client
  end

  # def new_battlestatus(username, new_battlestatus, team_colour) do
  #   :ok = PubSub.broadcast Teiserver.PubSub, "client_updates", {:new_battlestatus, username, new_battlestatus, team_colour}
  #   client = get_client(username)
  #   Map.merge(client, %{
  #     battlestatus: new_battlestatus,
  #     team_colour: team_colour,
  #   })
  #   |> add_client
  # end

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

  # It appears this isn't used but I suspect it will be at a later stage
  # def get_client_state(pid) do
  #   GenServer.call(pid, :get_state)
  # end

  def disconnect(name) do
    ConCache.delete(:clients, name)
    ConCache.update(:lists, :clients, fn value -> 
      new_value = value
      |> Enum.filter(fn v -> v != name end)

      {:ok, new_value}
    end)
  end
end