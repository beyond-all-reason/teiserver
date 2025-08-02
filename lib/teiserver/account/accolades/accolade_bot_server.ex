defmodule Teiserver.Account.AccoladeBotServer do
  @moduledoc """
  The accolade server is the interface point for the Accolade system.
  """
  use GenServer
  alias Teiserver.Config
  alias Teiserver.{Account, CacheUser, Room, Battle, Coordinator}
  alias Teiserver.Coordinator.CoordinatorCommands
  alias Teiserver.Account.AccoladeLib
  alias Phoenix.PubSub
  require Logger

  @spec max_miss_count :: float
  def max_miss_count do
    AccoladeLib.miss_count_limit() * 1.5
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  def handle_call(:client_state, _from, state) do
    {:reply, state.client, state}
  end

  @impl true
  def handle_cast({:update_client, new_client}, state) do
    {:noreply, %{state | client: new_client}}
  end

  def handle_cast({:merge_client, partial_client}, state) do
    {:noreply, %{state | client: Map.merge(state.client, partial_client)}}
  end

  @impl true
  def handle_info(:begin, _state) do
    Logger.debug("Starting up Accolade server")
    account = get_accolade_account()
    Teiserver.cache_put(:application_metadata_cache, "teiserver_accolade_userid", account.id)

    {user, client} =
      case CacheUser.internal_client_login(account.id) do
        {:ok, user, client} -> {user, client}
        :error -> raise "No accolade user found"
      end

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name,
      client: client
    }

    ~w(main accolades)
    |> Enum.each(fn room_name ->
      Room.get_or_make_room(room_name, user.id)
      Room.add_user_to_room(user.id, room_name)
      :ok = PubSub.subscribe(Teiserver.PubSub, "room:#{room_name}")
    end)

    :ok = PubSub.subscribe(Teiserver.PubSub, "legacy_user_updates:#{user.id}")

    # We only subscribe to this if we're not in test, if we are it'll generate a bunch of SQL errors
    # without actually breaking anything
    if not Application.get_env(:teiserver, Teiserver)[:test_mode] do
      :ok = PubSub.subscribe(Teiserver.PubSub, "global_match_updates")
    end

    {:noreply, state}
  end

  # Match ending
  def handle_info(
        %{channel: "global_match_updates", event: :match_completed, match_id: match_id},
        state
      ) do
    case Battle.get_match(match_id) do
      nil ->
        nil

      match ->
        duration = Timex.diff(match.finished, match.started, :second)

        if duration > 600 do
          if Config.get_site_config_cache("teiserver.Enable accolades") do
            post_match_messages(match)
          end
        else
          :ok
        end
    end

    {:noreply, state}
  end

  def handle_info(%{channel: "global_match_updates"}, state) do
    {:noreply, state}
  end

  # Direct/Room messaging
  def handle_info({:add_user_to_room, _userid, _room_name}, state), do: {:noreply, state}
  def handle_info({:remove_user_from_room, _userid, _room_name}, state), do: {:noreply, state}

  def handle_info({:new_message, _userid, _room_name, _message}, state), do: {:noreply, state}
  def handle_info({:new_message_ex, _userid, _room_name, _message}, state), do: {:noreply, state}

  def handle_info({:direct_message, from_id, parts}, state) when is_list(parts) do
    new_state =
      parts
      |> Enum.reduce(state, fn part, acc_state ->
        {_, new_state} = handle_info({:direct_message, from_id, part}, acc_state)
        new_state
      end)

    {:noreply, new_state}
  end

  def handle_info({:direct_message, sender_id, "$" <> command}, state) do
    cmd = Coordinator.Parser.parse_command(sender_id, "$#{command}")
    new_state = CoordinatorCommands.handle_command(cmd, state)

    {:noreply, new_state}
  end

  def handle_info({:direct_message, userid, message}, state) do
    if not CacheUser.is_bot?(userid) do
      case AccoladeLib.cast_accolade_chat(userid, {:user_message, message}) do
        nil ->
          CacheUser.send_direct_message(
            state.userid,
            userid,
            "I'm not currently awaiting feedback for a player"
          )

        _ ->
          :ok
      end
    end

    {:noreply, state}
  end

  def handle_info({:new_accolade, userid}, state) do
    CacheUser.send_direct_message(
      state.userid,
      userid,
      "You have been awarded a new accolade send $whoami to myself to see your collection."
    )

    {:noreply, state}
  end

  # Client inout
  def handle_info(%{channel: "client_inout", event: :login, userid: userid}, state) do
    :timer.send_after(500, {:do_client_inout, :login, userid})
    {:noreply, state}
  end

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error(
      "Accolade server handle_info error. No handler for msg of #{Kernel.inspect(msg)}"
    )

    {:noreply, state}
  end

  @spec get_accolade_account() :: Teiserver.Account.CacheUser.t()
  def get_accolade_account() do
    user =
      Account.get_user(nil,
        search: [
          email: "accolades_bot@teiserver.local"
        ]
      )

    case user do
      nil ->
        # Make account
        {:ok, account} =
          Account.script_create_user(%{
            name: "AccoladesBot",
            email: "accolades_bot@teiserver.local",
            icon:
              "fa-solid #{Teiserver.Account.AccoladeLib.icon()}" |> String.replace(" far ", " "),
            colour: "#0066AA",
            password: Account.make_bot_password(),
            roles: ["Bot", "Verified"],
            data: %{
              bot: true,
              moderator: false,
              lobby_client: "Teiserver Internal Process"
            }
          })

        Account.update_user_stat(account.id, %{
          country_override: Application.get_env(:teiserver, Teiserver)[:server_flag]
        })

        CacheUser.recache_user(account.id)
        account

      account ->
        account
    end
  end

  defp post_match_messages(%{id: match_id} = _match) do
    Logger.info("AccoladeBotServer post match messages for #{match_id}")

    # Get a list of all the players, then check if there are possible ratings for them
    memberships = Battle.list_match_memberships(search: [match_id: match_id])

    memberships
    |> Enum.each(fn %{user_id: userid} ->
      case AccoladeLib.get_possible_ratings(userid, memberships) do
        [] ->
          :ok

        possibles ->
          chosen = Enum.random(possibles)
          AccoladeLib.start_accolade_process(userid, chosen, match_id)
      end
    end)
  end

  @impl true
  @spec init(map()) :: {:ok, map()}
  def init(_opts) do
    Horde.Registry.register(
      Teiserver.AccoladesRegistry,
      "AccoladeBotServer",
      :accolade_bot
    )

    send(self(), :begin)
    {:ok, %{}}
  end
end
