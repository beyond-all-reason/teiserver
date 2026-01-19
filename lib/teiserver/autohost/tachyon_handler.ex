defmodule Teiserver.Autohost.TachyonHandler do
  @moduledoc """
  Handle a connection with an autohost using the tachyon protocol.

  This is treated separately from a player connection because they fulfill
  very different roles, have very different behaviour and states.
  """
  alias Teiserver.Autohost.Registry
  alias Teiserver.Bot.Bot
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Helpers.{TachyonParser, Collections}
  alias Teiserver.Tachyon.{Handler, Schema, Transport}
  alias Teiserver.Autohost
  alias Teiserver.TachyonBattle

  require Logger
  @behaviour Handler

  @type connected_state :: %{max_battles: non_neg_integer(), current_battles: non_neg_integer()}
  @type state :: %{
          autohost: Bot.t(),
          session_pid: pid(),
          state: :handshaking | {:connected, connected_state()}
        }

  def start_battle(conn_pid, battle_id, start_script) do
    send(conn_pid, {:start_battle, battle_id, start_script})
  end

  @spec subscribe_updates(pid(), DateTime.t()) :: :ok | {:error, reason :: term()}
  def subscribe_updates(conn_pid, since) do
    payload = %{since: DateTime.to_unix(since, :microsecond)}
    response = Transport.call_client(conn_pid, "autohost/subscribeUpdates", payload)

    case response do
      %{"status" => "failed", "reason" => reason} ->
        msg =
          case response["details"] do
            nil -> reason
            details -> "#{reason} - #{details}"
          end

        Logger.error("failed to subscribe to autohost updates: #{inspect(msg)}")
        {:error, msg}

      %{"status" => "success"} ->
        :ok
    end
  catch
    # in case the connection is terminating midway
    :exit, {:normal, _} -> :ok
  end

  @doc """
  send a message to the autohost with the given pid
  this calls returns when the ack to the request has been received.
  """
  @spec send_message(pid(), %{battle_id: TachyonBattle.id(), message: String.t()}) ::
          :ok | {:error, reason :: term()}
  def send_message(autohost, payload) when is_pid(autohost) do
    payload = %{battleId: payload.battle_id, message: payload.message}
    response = Transport.call_client(autohost, "autohost/sendMessage", payload)

    case response["status"] do
      "success" ->
        :ok

      "failed" ->
        err = response["reason"]

        case Map.get(response, "details") do
          nil -> {:error, err}
          details -> {:error, "#{err} - #{details}"}
        end
    end
  end

  @spec kill_battle(pid(), TachyonBattle.id()) :: :ok
  def kill_battle(autohost, battle_id) when is_pid(autohost) do
    response = Transport.call_client(autohost, "autohost/kill", %{battleId: battle_id})

    case response["status"] do
      "success" ->
        :ok

      "failed" ->
        err = response["reason"]

        case Map.get(response, "details") do
          nil -> {:error, err}
          details -> {:error, "#{err} - #{details}"}
        end
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
    Logger.metadata(actor_type: :autohost_conn, actor_id: state.autohost.id)

    case Teiserver.Autohost.SessionSupervisor.start_session(state.autohost, self()) do
      {:ok, session_pid} ->
        state = Map.put(state, :session_pid, session_pid)
        {:ok, state}

      {:error, reason} ->
        Logger.warning("Cannot start autohost session: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info({:start_battle, battle_id, start_script}, state) do
    mappings = %{
      engine_version: :engineVersion,
      game_name: :gameName,
      map_name: :mapName,
      start_pos_type: :startPosType,
      ally_teams:
        {:allyTeams,
         %{
           teams: {:teams, %{players: {:players, &player_to_tachyon/1}}}
         }},
      spectators: {:spectators, &player_to_tachyon/1}
    }

    start_script =
      start_script
      |> Collections.transform_map(mappings)
      |> Collections.remove_nil_vals()
      |> Map.put(:battleId, battle_id)

    opts = [cb_state: battle_id]
    {:request, "autohost/start", start_script, opts, state}
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
        # credo:disable-for-next-line Credo.Check.Design.TagTODO
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
  def handle_response("autohost/start", _battle_id, _resp, state) when state.session_pid == nil,
    do: {:ok, state}

  def handle_response("autohost/start", battle_id, response, state) do
    resp =
      case response do
        %{"status" => "failed", "reason" => reason} ->
          msg =
            case response["details"] do
              nil -> reason
              details -> "#{reason} - #{details}"
            end

          Logger.error("failed to start a battle: #{msg}")
          {:error, msg}

        %{"status" => "success", "data" => data} ->
          {:ok, %{ips: data["ips"], port: data["port"]}}
      end

    Autohost.Session.reply_battle_started(state.session_pid, battle_id, resp)
    {:ok, state}
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
          | {:player_chat_broadcast,
             %{
               destination: :allies | :all | :spectators,
               message: String.t(),
               user_id: T.userid()
             }}
          | {:player_chat_dm, %{message: String.t(), user_id: T.userid(), to_user_id: T.userid()}}
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
      case update["type"] do
        "player_joined" ->
          update = {:player_joined, %{user_id: user_id, player_number: update["playerNumber"]}}
          {:ok, %{battle_id: data["battleId"], time: time, update: update}}

        "player_left" ->
          reason =
            case update["reason"] do
              "lost_connection" -> :lost_connection
              "left" -> :left
              "kicked" -> :kicked
            end

          update = {:player_left, %{user_id: user_id, reason: reason}}
          {:ok, %{battle_id: data["battleId"], time: time, update: update}}

        "player_chat" ->
          if update["destination"] == "player" do
            case TachyonParser.parse_user_id(update["toUserId"]) do
              {:ok, id} ->
                update =
                  {:player_chat_dm,
                   %{message: update["message"], user_id: user_id, to_user_id: id}}

                {:ok, %{battle_id: data["battleId"], time: time, update: update}}

              err ->
                err
            end
          else
            dest =
              case update["destination"] do
                "allies" -> :allies
                "all" -> :all
                "spectators" -> :spectators
              end

            update =
              {:player_chat_broadcast,
               %{destination: dest, message: update["message"], user_id: user_id}}

            {:ok, %{battle_id: data["battleId"], time: time, update: update}}
          end

        "player_defeated" ->
          update = {:player_defeated, %{user_id: user_id}}
          {:ok, %{battle_id: data["battleId"], time: time, update: update}}

        "start" ->
          {:ok, %{battle_id: data["battleId"], time: time, update: :start}}

        "finished" ->
          update =
            {:finished, %{user_id: user_id, winning_ally_teams: update["winningAllyTeams"]}}

          {:ok, %{battle_id: data["battleId"], time: time, update: update}}

        "engine_message" ->
          update = {:engine_message, %{message: update["message"]}}
          {:ok, %{battle_id: data["battleId"], time: time, update: update}}

        "engine_warning" ->
          {:engine_warning, %{message: update["message"]}}
          {:ok, %{battle_id: data["battleId"], time: time, update: update}}

        "engine_crash" ->
          {:engine_warning, %{details: Map.get(update, "details")}}
          {:ok, %{battle_id: data["battleId"], time: time, update: update}}

        "engine_quit" ->
          {:ok, %{battle_id: data["battleId"], time: time, update: :engine_quit}}

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
          {:ok, %{battle_id: data["battleId"], time: time, update: update}}
      end
    end
  end

  def player_to_tachyon(p) when is_list(p), do: Enum.map(p, &player_to_tachyon/1)

  def player_to_tachyon(p) do
    %{
      userId: to_string(p.user_id),
      name: p.name,
      password: p.password
    }
  end
end
