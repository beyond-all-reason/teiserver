defmodule Teiserver.Bridge.BridgeServer do
  @moduledoc """
  The server used to read events from Teiserver and then use the DiscordBridgeBot to send onwards
  """
  alias Phoenix.PubSub
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.Bridge.CommandLib
  alias Teiserver.CacheUser
  alias Teiserver.Client
  alias Teiserver.Communication

  use GenServer

  require Logger

  def bot_name, do: "DiscordBridgeBot"

  @spec start_link(list()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], name: via_tuple())
  end

  @spec get_bridge_userid() :: User.id()
  def get_bridge_userid do
    Teiserver.cache_get(:application_metadata_cache, "teiserver_bridge_userid")
  end

  @spec call_bridge(any()) :: any()
  def call_bridge(message) do
    GenServer.call(via_tuple(), message)
  end

  @spec cast_bridge(any()) :: :ok
  def cast_bridge(message) do
    GenServer.cast(via_tuple(), message)
  end

  @spec send_bridge(any()) :: :ok
  def send_bridge(message) do
    bridge_pid = get_bridge_pid()
    send(bridge_pid, message)
  end

  @impl GenServer
  def handle_call(:client_state, _from, state) do
    {:reply, state.client, state}
  end

  @impl GenServer
  def handle_cast({:update_client, new_client}, state) do
    {:noreply, %{state | client: new_client}}
  end

  def handle_cast({:merge_client, partial_client}, state) do
    {:noreply, %{state | client: Map.merge(state.client, partial_client)}}
  end

  # The bridge is ready to start doing stuff
  def handle_cast(:READY, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_continue(:begin, _state) do
    state = do_begin()
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:recache, state) do
    Logger.info("Recaching")
    {:noreply, build_local_caches(state)}
  end

  # Metrics
  def handle_info({:update_stats, stat_name, value}, state) do
    channel_name =
      case stat_name do
        :client_count -> "Clients (counter)"
        :player_count -> "Players (counter)"
        :match_count -> "Matches (counter)"
        :lobby_count -> "Lobbies (counter)"
        _other -> nil
      end

    new_name =
      case stat_name do
        :client_count -> "Players online: #{value}"
        :player_count -> "Players in game: #{value}"
        :match_count -> "Ongoing battles: #{value}"
        :lobby_count -> "Open lobbies: #{value}"
        _other -> ""
      end

    Communication.rename_discord_channel(channel_name, new_name)

    {:noreply, state}
  end

  def handle_info(
        %{channel: "teiserver_client_messages:" <> _userid, event: :received_direct_message} =
          data,
        state
      ) do
    username = CacheUser.get_username(data.sender_id)

    CacheUser.send_direct_message(
      state.userid,
      data.sender_id,
      "I don't currently handle messages, sorry #{username}"
    )

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _userid}, state),
    do: {:noreply, state}

  def handle_info(%{channel: "teiserver_server", event: :started}, state) do
    if Communication.use_discord?() do
      Communication.new_discord_message(
        "Main chat",
        "Server startup for node #{Teiserver.node_name()}"
      )

      Communication.new_discord_message(
        "Server updates",
        "Teiserver startup for node #{Teiserver.node_name()}"
      )
    end

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_server", event: :prep_stop}, state) do
    if Communication.use_discord?() do
      Communication.new_discord_message(
        "Server updates",
        "Teiserver shutdown for node #{Teiserver.node_name()}"
      )
    end

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_server"}, state), do: {:noreply, state}

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error("BridgeServer handle_info error. No handler for msg of #{Kernel.inspect(msg)}")
    {:noreply, state}
  end

  defp do_begin do
    Logger.info("Starting up Bridge server")
    account = get_bridge_account()
    Teiserver.cache_put(:application_metadata_cache, "teiserver_bridge_userid", account.id)
    {:ok, user, client} = CacheUser.internal_client_login(account.id)

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name,
      lobby_host: false,
      user: user,
      client: client,
      recent_bridged_messages: %{}
    }

    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_server")
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_client_messages:#{user.id}")

    build_local_caches(state)
  end

  defp build_local_caches(state) do
    CommandLib.cache_discord_commands()
    Communication.pre_cache_discord_channels()

    state
  end

  @spec get_bridge_account() :: Teiserver.CacheUser.t() | map()
  def get_bridge_account do
    user =
      Account.get_user(nil,
        search: [
          email: "bridge@teiserver.local"
        ]
      )

    case user do
      nil ->
        # Make account
        {:ok, account} =
          Account.script_create_user(%{
            name: bot_name(),
            email: "bridge@teiserver.local",
            icon: "fa-brands fa-discord",
            colour: "#0066AA",
            password: Account.make_bot_password(),
            roles: ["Bot", "Verified", "Server"],
            data: %{
              bot: true,
              moderator: false,
              lobby_client: "Teiserver Internal Process"
            }
          })

        Account.update_user_stat(account.id, %{
          country_override: Application.get_env(:teiserver, Teiserver)[:server_flag]
        })

        CacheUser.deprecated_recache_user(account.id)
        account

      account ->
        account
    end
  end

  @impl GenServer
  @spec init(map()) :: {:ok, term(), {:continue, term()}}
  def init(_opts) do
    Process.flag(:trap_exit, true)
    Logger.metadata(request_id: "BridgeServer")

    {:ok, %{}, {:continue, :begin}}
  end

  @impl GenServer
  def terminate(_reason, state) do
    Map.get(state, :userid)
    |> Client.disconnect("bridge terminate")
  end

  @spec get_bridge_pid() :: pid | nil
  def get_bridge_pid do
    case Registry.lookup(Teiserver.ServerRegistry, "BridgeServer") do
      [{pid, _data}] -> pid
      _x -> nil
    end
  end

  defp via_tuple, do: {:via, Registry, {Teiserver.ServerRegistry, "BridgeServer"}}
end
