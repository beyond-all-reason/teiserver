defmodule Teiserver.Bridge.BridgeServer do
  @moduledoc """
  The server used to read events from Teiserver and then use the DiscordBridgeBot to send onwards
  """

  alias Nostrum.Api.Channel
  alias Phoenix.PubSub
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.Bridge.CommandLib
  alias Teiserver.CacheUser
  alias Teiserver.Client
  alias Teiserver.Communication
  alias Teiserver.Config
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

  @spec server_update_channel() :: integer() | nil
  def server_update_channel,
    do: Config.get_site_config_cache("teiserver.Discord channel #server-updates")

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
    config_key =
      case stat_name do
        :client_count -> "teiserver.Discord counter clients"
        :player_count -> "teiserver.Discord counter players"
        :match_count -> "teiserver.Discord counter matches"
        :lobby_count -> "teiserver.Discord counter lobbies"
        _other -> ""
      end

    channel_id = Config.get_site_config_cache(config_key)

    new_name =
      case stat_name do
        :client_count -> "Players online: #{value}"
        :player_count -> "Players in game: #{value}"
        :match_count -> "Ongoing battles: #{value}"
        :lobby_count -> "Open lobbies: #{value}"
        _other -> ""
      end

    change_channel_name(channel_id, new_name)

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
      # Main
      channel_id = Config.get_site_config_cache("teiserver.Discord channel #main")

      if channel_id do
        Communication.new_discord_message(
          channel_id,
          "Teiserver startup for node #{Teiserver.node_name()}"
        )
      end

      # Server
      channel_id = server_update_channel()

      if channel_id do
        Communication.new_discord_message(
          channel_id,
          "Teiserver startup for node #{Teiserver.node_name()}"
        )
      end
    end

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_server", event: :prep_stop}, state) do
    if Communication.use_discord?() do
      channel_id = Config.get_site_config_cache("teiserver.Discord channel #server-updates")

      if channel_id do
        Communication.new_discord_message(
          channel_id,
          "Teiserver shutdown for node #{Teiserver.node_name()}"
        )
      end
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
    channel_lookup =
      [
        "teiserver.Discord channel #main",
        "teiserver.Discord channel #newbies",
        "teiserver.Discord channel #promote",
        "teiserver.Discord channel #moderation-reports",
        "teiserver.Discord channel #moderation-actions",
        "teiserver.Discord channel #server-updates",
        "teiserver.Discord channel #telemetry-infologs",
        "teiserver.Discord forum #gdt-discussion",
        "teiserver.Discord forum #gdt-voting"
      ]
      |> Enum.map(fn key ->
        channel_id = Config.get_site_config_cache(key)

        if channel_id do
          [_prefix, room] = String.split(key, "#")

          {room, channel_id}
        end
      end)
      |> Enum.reject(&(&1 == nil))
      |> Map.new()

    Teiserver.store_put(:application_metadata_cache, :discord_channel_lookup, channel_lookup)

    CommandLib.cache_discord_commands()
    Communication.pre_cache_discord_channels()

    Map.merge(state, %{
      channel_lookup: channel_lookup
    })
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

  @spec change_channel_name(String.t(), String.t()) :: boolean()
  def change_channel_name(_channel_id, ""), do: false
  def change_channel_name(nil, _new_name), do: false
  def change_channel_name(0, _new_name), do: false

  def change_channel_name(channel_id, new_name) do
    Channel.modify(channel_id, %{
      name: new_name
    })

    false
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
