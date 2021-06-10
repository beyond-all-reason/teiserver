defmodule Teiserver.Director.CoordinatorServer do
  use GenServer
  alias Teiserver.{Account, User, Room}
  alias Phoenix.PubSub
  require Logger

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_info(:begin, _state) do
    Logger.debug("Starting up Director coordinator")
    account = get_coordinator_account()
    {:ok, user} = User.internal_client_login(account.id)

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name,
      battle_host: false,
      user: user,
      queues: [],
      ready_queue_id: nil,
      consuls: %{}
    }

    # Join two channels of interest
    # ~w(main coordinator)
    ~w(coordinator)
    |> Enum.each(fn room_name ->
      Room.get_or_make_room(room_name, user.id)
      Room.add_user_to_room(user.id, room_name)
      :ok = PubSub.subscribe(Central.PubSub, "room:#{room_name}")
    end)

    :ok = PubSub.subscribe(Central.PubSub, "user_updates:#{user.id}")

    {:noreply, state}
  end

  def handle_info({:request_consul, battle_id}, state) do
    {consul_id, consul_state} = get_next_consul(state.consuls)

    case consul_state do
      :idle ->
        nil

      :disconnected ->
        connect_consul(consul_id)

      nil ->
        # consul_id = create_consul()
        # connect_consul(consul_id)
        nil
    end

    {:noreply, state}
  end

  def handle_info({:remove_consul, battle_id}, state) do
    {:noreply, state}
  end

  # Direct/Room messaging
  def handle_info({:add_user_to_room, _userid, _room_name}, state), do: {:noreply, state}
  def handle_info({:remove_user_from_room, _userid, _room_name}, state), do: {:noreply, state}

  def handle_info({:new_message, userid, room_name, _message}, state) do
    # If it's us sending it, don't reply
    if userid != state.userid do
      username = User.get_username(userid)
      Room.send_message(state.userid, room_name, "I don't currently handle messages, sorry #{username}")
    end
    {:noreply, state}
  end

  def handle_info({:direct_message, userid, _message}, state) do
    # If it's us sending it, don't reply
    username = User.get_username(userid)
    User.send_direct_message(state.userid, userid, "I don't currently handle messages, sorry #{username}")
    {:noreply, state}
  end

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error("Coordinator handle_info error. No handler for msg of #{Kernel.inspect msg}")
    {:noreply, state}
  end

  @spec get_next_consul(Map.t()) :: {integer(), :idle | :disconnected} | {nil, nil}
  defp get_next_consul(consuls) do
    available = consuls
    |> Enum.group_by(fn {_k, {_pid, c_state}} ->
      c_state
    end, fn {consul_id, _v} ->
      consul_id
    end)

    cond do
      Map.has_key?(available, :idle) ->
        {hd(available[:idle]), :idle}

      Map.has_key?(available, :disconnected) ->
        {hd(available[:disconnected]), :disconnected}

      true ->
        {nil, nil}
    end
  end

  defp connect_consul(id) do
    db_user = Account.get_user!(id)
    token = User.create_token(db_user)
    {:ok, user} = User.try_login(token, "127.0.0.1", "Teiserver Internal Process")

    :timer.sleep(1000)
  end

  @spec get_coordinator_account() :: Central.Account.User.t()
  def get_coordinator_account() do
    user = Account.get_user(nil, search: [
      exact_name: "Coordinator"
    ])

    case user do
      nil ->
        # Make account
        {:ok, account} = Account.create_user(%{
          name: "Coordinator",
          email: "coordinator@teiserver",
          icon: "fa-solid fa-sitemap",
          colour: "#AA00AA",
          admin_group_id: Teiserver.internal_group_id(),
          password: make_password(),
          data: %{
            bot: true,
            moderator: true,
            verified: true,
            country_override: "GB",# TODO: Make this configurable
            lobbyid: "Teiserver Internal Process"
          }
        })

        Account.create_group_membership(%{
          user_id: account.id,
          group_id: Teiserver.internal_group_id()
        })

        User.recache_user(account.id)
        account

      account ->
        account
    end
  end

  @spec make_password() :: String.t
  defp make_password() do
    :crypto.strong_rand_bytes(64) |> Base.encode64(padding: false) |> binary_part(0, 64)
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    {:ok,
     %{
       battle_id: opts[:battle_id],
       game_mode: "team"
     }}
  end
end
