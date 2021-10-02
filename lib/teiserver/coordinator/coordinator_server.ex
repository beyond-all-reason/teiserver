defmodule Teiserver.Coordinator.CoordinatorServer do
  @moduledoc """
  The coordinator server is the interface point for the Coordinator system. Consuls are invisible (to the players) processes
  performing their actions in the name of the coordinator
  """
  use GenServer
  alias Teiserver.{Account, User, Clans, Room, Coordinator}
  alias Teiserver.Coordinator.AutomodServer
  alias Phoenix.PubSub
  require Logger

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_info(:begin, _state) do
    Logger.debug("Starting up Coordinator coordinator")
    account = get_coordinator_account()
    ConCache.put(:application_metadata_cache, "teiserver_coordinator_userid", account.id)

    user = case User.internal_client_login(account.id) do
      {:ok, user} -> user
      :error -> throw "No coordinator user found"
    end

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name,
      lobby_host: false,
      user: user,
      queues: [],
      ready_queue_id: nil,
      consuls: %{}
    }

    ~w(coordinator moderators)
    |> Enum.each(fn room_name ->
      Room.get_or_make_room(room_name, user.id)
      Room.add_user_to_room(user.id, room_name)
      :ok = PubSub.subscribe(Central.PubSub, "room:#{room_name}")
    end)

    # Now join the clan channels
    Clans.list_clans()
    |> Enum.each(fn clan ->
      room_name = Room.clan_room_name(clan.tag)
      Room.get_or_make_room(room_name, user.id, clan.id)
      Room.add_user_to_room(user.id, room_name)
      :ok = PubSub.subscribe(Central.PubSub, "room:#{room_name}")
    end)

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_inout")
    :ok = PubSub.subscribe(Central.PubSub, "legacy_user_updates:#{user.id}")

    {:noreply, state}
  end

  # Direct/Room messaging
  def handle_info({:add_user_to_room, _userid, _room_name}, state), do: {:noreply, state}
  def handle_info({:remove_user_from_room, _userid, _room_name}, state), do: {:noreply, state}

  # def handle_info({:new_message, userid, "coordinator", _message}, state) do
  #   # If it's us sending it, don't reply
  #   if userid != state.userid do
  #     username = User.get_username(userid)
  #     Room.send_message(state.userid, "coordinator", "I don't currently handle messages, sorry #{username}")
  #   end
  #   {:noreply, state}
  # end
  def handle_info({:new_message, _userid, _room_name, _message}, state) do
    {:noreply, state}
  end

  def handle_info({:direct_message, fromid, "$" <> command}, state) do
    new_state = case command do
      "check " <> remaining ->
        case User.get_userid(remaining) do
          nil ->
            User.send_direct_message(state.userid, fromid, "Unable to find a user with that name")
          userid ->
            result = AutomodServer.check_user(userid)
            User.send_direct_message(state.userid, fromid, "Automod result: #{result}")
        end
        state

      _ ->
        username = User.get_username(fromid)
        User.send_direct_message(state.userid, fromid, "I don't currently handle messages, sorry #{username}")
        state
    end
    {:noreply, new_state}
  end

  def handle_info({:direct_message, userid, _message}, state) do
    username = User.get_username(userid)
    User.send_direct_message(state.userid, userid, "I don't currently handle messages, sorry #{username}")
    {:noreply, state}
  end

  # Client inout
  def handle_info({:client_inout, :login, userid}, state) do
    user = User.get_user_by_id(userid)
    if User.is_warned?(user) do
      [_ | expires] = user.warned
      if expires == nil do
        Coordinator.send_to_user(userid, "This is a reminder that you received a formal warning for misbehaving. This is your last warning and this warning does not expire.")
      else
        Coordinator.send_to_user(userid, "This is a reminder that you recently received a formal warning for misbehaving, this warning will expire #{expires}.")
      end
    end
    {:noreply, state}
  end
  def handle_info({:client_inout, :disconnect, _userid, _reason}, state), do: {:noreply, state}

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error("Coordinator handle_info error. No handler for msg of #{Kernel.inspect msg}")
    {:noreply, state}
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
            country_override: Application.get_env(:central, Teiserver)[:server_flag],
            lobby_client: "Teiserver Internal Process"
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
  def init(_opts) do
    ConCache.put(:teiserver_consul_pids, :coordinator, self())
    send(self(), :begin)
    {:ok, %{}}
  end
end
