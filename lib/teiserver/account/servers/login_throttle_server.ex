defmodule Teiserver.Account.LoginThrottleServer do
  @moduledoc false
  use GenServer
  require Logger
  alias Teiserver.{Account, User}

  @impl true
  def handle_call(:queue_size, _from, state) do
    result = ~w(standard_queue vip_queue contributor_queue moderator_queue)a
      |> Enum.map(fn key ->
        Map.get(state, key, []) |> Enum.count
      end)
      |> Enum.sum()

    {:reply, result, state}
  end

  @impl true
  def handle_info({:login_attempt, userid}, state) do
    user = Account.get_user_by_id(userid)

    queue_key = cond do
      User.has_all_roles?(user, ["Moderator"]) -> :moderator_queue
      User.has_all_roles?(user, ["Contributor"]) -> :contributor_queue
      User.has_all_roles?(user, ["VIP"]) -> :vip_queue
      true -> :standard_queue
    end

    # Insert them into the front of the queue list
    queue = Map.get(state, queue_key, [])
    new_queue = [userid | queue]
    new_state = Map.put(state, queue_key, new_queue)

    {:noreply, new_state}
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(_) do
    Logger.metadata(request_id: "LoginThrottleServer")

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "LoginThrottleServer",
      "LoginThrottleServer"
    )

    {:ok,
      %{
        standard_queue: [],
        vip_queue: [],
        contributor_queue: [],
        moderator_queue: []
      }
    }
  end
end
