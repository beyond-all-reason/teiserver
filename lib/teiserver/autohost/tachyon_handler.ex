defmodule Teiserver.Autohost.TachyonHandler do
  @moduledoc """
  Handle a connection with an autohost using the tachyon protocol.

  This is treated separately from a player connection because they fulfill
  very different roles, have very different behaviour and states.
  """
  alias Teiserver.Autohost.Registry
  alias Teiserver.Bot.Bot
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Helpers.TachyonParser
  alias Teiserver.Tachyon.{Handler, Schema}
  alias Teiserver.TachyonBattle

  require Logger
  @behaviour Handler

  @type connected_state :: %{max_battles: non_neg_integer(), current_battles: non_neg_integer()}
  @type state :: %{
          autohost: Bot.t(),
          state: :handshaking | {:connected, connected_state()}
        }

  @type start_response :: %{
          ips: [String.t()],
          port: integer(),
          engine: %{version: String.t()},
          game: %{springName: String.t()},
          map: %{springName: String.t()}
        }

  # TODO: there should be some kind of retry here
  @spec start_battle(Bot.id(), Teiserver.Autohost.start_script()) ::
          {:ok, start_response()} | {:error, term()}
  def start_battle(autohost_id, start_script) do
    case Registry.lookup(autohost_id) do
      {pid, _} ->
        send(pid, {:start_battle, start_script, self()})

        # This receive is a bit iffy and may cause problem with controlled shutdown
        # Ideally, the same way player work, there would be a GenServer decoupled
        # from the actual websocket connection, but for now, this poor's man
        # GenServer.call will have to do
        receive do
          {:start_battle_response, resp} -> resp
        after
          10_000 -> {:error, :timeout}
        end

      _ ->
        {:error, :no_host_available}
    end
  end

  @impl Handler
  def connect(conn) do
    autohost = conn.assigns[:token].bot
    {:ok, %{autohost: autohost, state: :handshaking}}
  end

  @impl Handler
  @spec init(state()) :: Handler.result()
  def init(state) do
    {:request, "autohost/subscribeUpdates",
     %{since: DateTime.utc_now() |> DateTime.to_unix(:microsecond)}, [], state}
  end

  @impl Handler
  def handle_info({:start_battle, start_script, sender}, state) do
    {:request, "autohost/start", start_script, [cb_state: sender], state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  @impl Handler
  @spec handle_command(
          Schema.command_id(),
          Schema.message_type(),
          Schema.message_id(),
          term(),
          state()
        ) :: WebSock.handle_result()

  def handle_command("system/disconnect", "request", _message_id, _message, state) do
    {:stop, :normal, state}
  end

  def handle_command("autohost/status", "event", _msg_id, msg, %{state: :handshaking} = state) do
    %{"data" => %{"maxBattles" => max_battles, "currentBattles" => current}} = msg

    Logger.info(
      "Autohost (id=#{state.autohost.id}) connecting #{state.autohost.id} with #{inspect(msg["data"])}"
    )

    state = %{
      state
      | state:
          {:connected,
           %{
             max_battles: max_battles,
             current_battles: current
           }}
    }

    case Registry.register(%{
           id: state.autohost.id,
           max_battles: max_battles,
           current_battles: current
         }) do
      {:error, {:already_registered, _pid}} ->
        # TODO: maybe we should handle that by disconnecting the existing one?
        {:stop, :normal, state}

      _ ->
        {:ok, state}
    end
  end

  def handle_command("autohost/status", "event", _, msg, state) do
    %{"data" => %{"maxBattles" => max_battles, "currentBattles" => current}} = msg

    Registry.update_value(state.autohost.id, fn _ ->
      %{id: state.autohost.id, max_battles: max_battles, current_battles: current}
    end)

    state = %{state | state: {:connected, %{max_battles: max_battles, current_battles: current}}}
    {:ok, state}
  end

  def handle_command(
        command_id,
        _message_type,
        message_id,
        _message,
        %{state: :handshaking} = state
      ) do
    resp =
      Schema.error_response(
        command_id,
        message_id,
        :invalid_request,
        "The first message after connection must be `status`"
      )
      |> Jason.encode!()

    # 1000 = close normal
    {:stop, :normal, 1000, [{:text, resp}], state}
  end

  def handle_command("autohost/update", "event", _msg_id, msg, state) do
    parsed = parse_update_event(msg["data"])
    Logger.debug("parsed message #{inspect(parsed)}")

    case parsed do
      {:ok, ev} ->
        TachyonBattle.send_update_event(ev)
        {:ok, state}

      {:error, reason} ->
        Logger.error("error parsing event: #{inspect(reason)} - #{inspect(msg["data"])}")
        {:stop, {:shutdown, {:error, reason}}, state}
    end
  end

  def handle_command(_command_id, _message_type, _message_id, _message, state) do
    {:error_response, :command_unimplemented, state}
  end

  @impl true
  def handle_response("autohost/start", reply_to, response, state) do
    notify_autohost_started(reply_to, response)
    {:ok, state}
  end

  def handle_response("autohost/subscribeUpdates", _, _response, state) do
    # TODO: handle potential failure here
    # for example, autohost refuses any subscription with `since` older than 5 minutes
    {:ok, state}
  end

  defp notify_autohost_started(reply_to, %{"status" => "failed", "reason" => reason} = msg) do
    msg =
      case msg["details"] do
        nil -> reason
        details -> "#{reason} - #{details}"
      end

    Logger.error("failed to start a battle: #{msg}")
    send(reply_to, {:start_battle_response, {:error, msg}})
  end

  defp notify_autohost_started(reply_to, %{"status" => "success", "data" => data}) do
    send(
      reply_to,
      {:start_battle_response,
       {:ok,
        %{
          ips: data["ips"],
          port: data["port"]
        }}}
    )
  end

  @type update_event_data ::
          {:player_joined, %{user_id: T.userid(), player_number: integer()}}
          | {:player_left, %{user_id: T.userid(), reason: :lost_connection | :left | :kicked}}
          | {:player_defeated, %{user_id: T.userid()}}
          | :start
          | {:finished, %{user_id: T.userid(), winning_ally_teams: nonempty_list(integer())}}
          | {:engine_message, %{message: String.t()}}
          | {:engine_warning, %{message: String.t()}}
          | {:engine_crash, %{details: String.t() | nil}}
          | :engine_quit
          | {:luamsg,
             %{
               user_id: T.userid(),
               script: :ui | :game | :rules,
               ui_mode: :all | :allies | :spectators | nil,
               data: String.t()
             }}
  @type update_event :: %{
          battle_id: TachyonBattle.id(),
          time: DateTime.t(),
          update: update_event_data()
        }

  # Note: this is not truly parsing, but more translating a known structure into
  # something more idiomatic. The json schema handle the actual validation so
  # when this function is called, the structure is known
  @doc false
  @spec parse_update_event(map()) :: {:ok, update_event()} | {:error, reason :: term()}
  def parse_update_event(data) do
    update = data["update"]

    user_id =
      case Map.get(update, "userId") do
        nil -> {:ok, nil}
        raw -> TachyonParser.parse_user_id(raw)
      end

    with {:ok, time} <- DateTime.from_unix(data["time"], :microsecond),
         {:ok, user_id} <- user_id do
      parsed_update =
        case update["type"] do
          "player_joined" ->
            {:player_joined, %{user_id: user_id, player_number: update["playerNumber"]}}

          "player_left" ->
            reason =
              case update["reason"] do
                "lost_connection" -> :lost_connection
                "left" -> :left
                "kicked" -> :kicked
              end

            {:player_left, %{user_id: user_id, reason: reason}}

          "player_defeated" ->
            {:player_defeated, %{user_id: user_id}}

          "start" ->
            :start

          "finished" ->
            {:finished, %{user_id: user_id, winning_ally_teams: update["winningAllyTeams"]}}

          "engine_message" ->
            {:engine_message, %{message: update["message"]}}

          "engine_warning" ->
            {:engine_warning, %{message: update["message"]}}

          "engine_crash" ->
            {:engine_warning, %{details: Map.get(update, "details")}}

          "engine_quit" ->
            :engine_quit

          "luamsg" ->
            script =
              case update["script"] do
                "ui" -> :ui
                "game" -> :game
                "rules" -> :rules
              end

            ui_mode =
              case Map.get(update, "uiMode") do
                nil -> nil
                "all" -> :all
                "allies" -> :allies
                "spectators" -> :spectators
              end

            {:luamsg, %{user_id: user_id, script: script, ui_mode: ui_mode, data: update["data"]}}
        end

      {:ok, %{battle_id: data["battleId"], time: time, update: parsed_update}}
    end
  end
end
