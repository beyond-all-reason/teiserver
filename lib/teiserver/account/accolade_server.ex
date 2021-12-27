defmodule Teiserver.Account.AccoladeServer do
  @moduledoc """
  The accolade server is the interface point for the Accolade system.
  """
  use GenServer
  alias Teiserver.{Account, User, Room}
  alias Phoenix.PubSub
  require Logger

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_info(:begin, _state) do
    Logger.debug("Starting up Accolade server")
    account = get_accolade_account()
    ConCache.put(:application_metadata_cache, "teiserver_accolade_userid", account.id)

    user = case User.internal_client_login(account.id) do
      {:ok, user} -> user
      :error -> throw "No accolade user found"
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

    ~w(main accolades)
    |> Enum.each(fn room_name ->
      Room.get_or_make_room(room_name, user.id)
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

  def handle_info({:new_message, _userid, _room_name, _message}, state), do: {:noreply, state}
  def handle_info({:new_message_ex, _userid, _room_name, _message}, state), do: {:noreply, state}

  def handle_info({:direct_message, userid, _message}, state) do
    User.send_direct_message(state.userid, userid, "I don't handle messages. Yet.")
    {:noreply, state}
  end

  # Client inout
  def handle_info({:client_inout, :login, userid}, state) do
    :timer.send_after(500, {:do_client_inout, :login, userid})
    {:noreply, state}
  end

  def handle_info({:client_inout, :disconnect, _userid, _reason}, state), do: {:noreply, state}

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error("Accolade server handle_info error. No handler for msg of #{Kernel.inspect msg}")
    {:noreply, state}
  end

  @spec get_accolade_account() :: Central.Account.User.t()
  def get_accolade_account() do
    user = Account.get_user(nil, search: [
      exact_name: "Accolade"
    ])

    case user do
      nil ->
        # Make account
        {:ok, account} = Account.create_user(%{
          name: "AccoladesBot",
          email: "accolades_bot@teiserver",
          icon: "fas #{Teiserver.Account.AccoladeLib.icon()}" |> String.replace(" far ", " "),
          colour: "#0066AA",
          admin_group_id: Teiserver.internal_group_id(),
          password: make_password(),
          data: %{
            bot: true,
            moderator: false,
            verified: true,
            lobby_client: "Teiserver Internal Process"
          }
        })

        Account.update_user_stat(account.id, %{
          country_override: Application.get_env(:central, Teiserver)[:server_flag],
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
    ConCache.put(:teiserver_consul_pids, :accolade, self())
    send(self(), :begin)
    {:ok, %{}}
  end
end
