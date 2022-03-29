defmodule Teiserver.Account.AccoladeBotServer do
  @moduledoc """
  The accolade server is the interface point for the Accolade system.
  """
  use GenServer
  alias Teiserver.{Account, User, Room, Battle, Coordinator}
  alias Teiserver.Coordinator.CoordinatorCommands
  alias Teiserver.Account.AccoladeLib
  alias Phoenix.PubSub
  require Logger

  def max_miss_count do
    AccoladeLib.miss_count_limit() * 1.5
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_info(:begin, _state) do
    Logger.debug("Starting up Accolade server")
    account = get_accolade_account()
    ConCache.put(:application_metadata_cache, "teiserver_accolade_userid", account.id)

    user = case User.internal_client_login(account.id) do
      {:ok, user} -> user
      :error -> raise "No accolade user found"
    end

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name
    }

    ~w(main accolades)
    |> Enum.each(fn room_name ->
      Room.get_or_make_room(room_name, user.id)
      Room.add_user_to_room(user.id, room_name)
      :ok = PubSub.subscribe(Central.PubSub, "room:#{room_name}")
    end)

    :ok = PubSub.subscribe(Central.PubSub, "legacy_user_updates:#{user.id}")

    # We only subscribe to this if we're not in test, if we are it'll generate a bunch of SQL errors
    # without actually breaking anything
    if not Application.get_env(:central, Teiserver)[:test_mode] do
      :ok = PubSub.subscribe(Central.PubSub, "teiserver_global_match_updates")
    end

    {:noreply, state}
  end

  # Match ending
  def handle_info({:global_match_updates, :match_completed, match_id}, state) do
    case Battle.get_match(match_id) do
      nil ->
        nil
      match ->
        duration = Timex.diff(match.finished, match.started, :second)
        if duration > 600 do
          post_match_messages(match)
        else
          :ok
        end
    end

    {:noreply, state}
  end
  def handle_info({:global_match_updates, _, _}, state), do: {:noreply, state}

  # Direct/Room messaging
  def handle_info({:add_user_to_room, _userid, _room_name}, state), do: {:noreply, state}
  def handle_info({:remove_user_from_room, _userid, _room_name}, state), do: {:noreply, state}

  def handle_info({:new_message, _userid, _room_name, _message}, state), do: {:noreply, state}
  def handle_info({:new_message_ex, _userid, _room_name, _message}, state), do: {:noreply, state}

  def handle_info({:direct_message, sender_id, "$" <> command}, state) do
    cmd = Coordinator.Parser.parse_command(sender_id, "$#{command}")
    new_state = CoordinatorCommands.handle_command(cmd, state)

    {:noreply, new_state}
  end

  def handle_info({:direct_message, userid, message}, state) do
    case AccoladeLib.cast_accolade_chat(userid, {:user_message, message}) do
      nil ->
        User.send_direct_message(state.userid, userid, "I'm not currently awaiting feedback for a player")
      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info({:new_accolade, userid}, state) do
    User.send_direct_message(state.userid, userid, "You have been awarded a new accolade send $whoami to myself to see your collection.")
    {:noreply, state}
  end

  # Client inout
  def handle_info({:client_inout, :login, userid}, state) do
    :timer.send_after(500, {:do_client_inout, :login, userid})
    {:noreply, state}
  end

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error("Accolade server handle_info error. No handler for msg of #{Kernel.inspect msg}")
    {:noreply, state}
  end

  @spec get_accolade_account() :: Central.Account.User.t()
  def get_accolade_account() do
    user = Account.get_user(nil, search: [
      exact_name: "AccoladesBot"
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

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(_opts) do
    ConCache.put(:teiserver_accolade_pids, :accolade_bot, self())
    Registry.register(
      Teiserver.ServerRegistry,
      "AccoladeBotServer",
      :accolade_bot
    )

    send(self(), :begin)
    {:ok, %{}}
  end
end
