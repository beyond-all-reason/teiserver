defmodule Teiserver.Client do
  alias Phoenix.PubSub

  def create(name, pid, protocol) do
    %{
      pid: pid,
      name: name,
      protocol: protocol,
      in_game: false,
      away: false,
      rank: 1,
      moderator: 0,
      bot: 0,
      battlestatus: 0
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

  # In addition to updating the client
  # it will trigger a broadcast of the update to all other clients
  # State is only used to enable sending of a message
  def update(updated_client) do
    add_client(updated_client)
    PubSub.broadcast :teiserver_pubsub, "client_update", updated_client
    updated_client
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
  end

  def list_clients() do
    ConCache.get(:lists, :clients)
    |> Enum.map(fn client_id -> ConCache.get(:clients, client_id) end)
  end

  def get_client_state(pid) do
    GenServer.call(pid, :get_state)
  end
end