defmodule Teiserver.Client do
  alias Phoenix.PubSub

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

  def create_from_user(user, client) do
    Map.merge(client, %{
      rank: user.rank,
      moderator: (user.moderator == 1),
      bot: (user.bot == 1)
    })
  end

  def create_from_bits([0], client) do
    Map.merge(client, %{
      in_game: 0,
      away: 0
    })
  end
  def create_from_bits(bits, client) do
    [in_game, away, _r1, _r2, _r3, _moderator, _bot | _] = bits ++ [0,0,0,0,0,0,0,0,0]
    Map.merge(client, %{
      in_game: (in_game == 1),
      away: (away == 1),
      # rank: r1 + r2 + r3,
      # moderator: (moderator == 1),
      # bot: (bot == 1)
    })
  end

  def to_bits(client) do
    [r1, r2, r3 | _] = Integer.digits(client.rank, 2) ++ [0, 0, 0]
    [
      (if client.in_game, do: 1, else: 0),
      (if client.away, do: 1, else: 0),
      r1,
      r2,
      r3,
      (if client.moderator, do: 1, else: 0),
      (if client.bot, do: 1, else: 0)
    ]
  end

  def update(updated_client) do
    add_client(updated_client)
    PubSub.broadcast Teiserver.PubSub, "client_updates", {:updated_client, updated_client}
    updated_client
  end

  def new_status(username, status) do
    client = get_client(username)
    Map.merge(client, %{
      status: status
    })
    |> add_client()
    PubSub.broadcast Teiserver.PubSub, "client_updates", {:updated_client_status, username, status}
  end

  def new_battlestatus(username, new_battlestatus, team_colour) do
    client = get_client(username)
    :ok = PubSub.broadcast Teiserver.PubSub, "client_updates", {:new_battlestatus, username, new_battlestatus, team_colour}
    updated_client = Map.merge(client, %{
      battlestatus: new_battlestatus,
      team_colour: team_colour
    })
    add_client(updated_client)
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

  def list_clients() do
    ConCache.get(:lists, :clients)
    |> Enum.map(fn username -> ConCache.get(:clients, username) end)
  end

  def get_client_state(pid) do
    GenServer.call(pid, :get_state)
  end
end