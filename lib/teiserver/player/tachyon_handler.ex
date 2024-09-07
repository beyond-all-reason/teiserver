defmodule Teiserver.Player.TachyonHandler do
  @moduledoc """
  Player specific code to handle tachyon logins and actions
  """

  alias Teiserver.Tachyon.Schema
  alias Teiserver.Tachyon.Handler
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Player
  alias Teiserver.Matchmaking

  @behaviour Handler

  @type state :: %{user: T.user()}

  @impl Handler
  def connect(conn) do
    # TODO: get the IP from request (somehow)
    ip = "127.0.0.1"
    lobby_client = conn.assigns[:token].application.uid
    user = conn.assigns[:token].owner

    case Teiserver.CacheUser.tachyon_login(user, ip, lobby_client) do
      {:ok, user} ->
        {:ok, %{user: user}}

      {:error, :rate_limited, msg} ->
        {:error, 429, msg}

      {:error, msg} ->
        {:error, 403, msg}
    end
  end

  @impl Handler
  @spec init(%{user: T.user()}) :: WebSock.handle_result()
  def init(initial_state) do
    # this is inside the process that maintain the connection
    {:ok, _sess_mon_ref} = setup_session(initial_state.user.id)
    {:ok, initial_state}
  end

  @impl Handler
  def handle_info({:notify_found, queue_id, timeout_ms}, state) do
    resp =
      Schema.event("matchmaking/found", %{
        queueId: queue_id,
        timeoutMs: timeout_ms
      })

    {:push, {:text, resp |> Jason.encode!()}, state}
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
    Player.Session.disconnect(state.user.id)

    {:stop, :normal, state}
  end

  def handle_command("matchmaking/list" = cmd_id, "request", message_id, _message, state) do
    queues =
      Matchmaking.list_queues()
      |> Enum.map(fn {qid, queue} ->
        %{
          id: qid,
          name: queue.name,
          numOfTeams: queue.team_count,
          teamSize: queue.team_size,
          ranked: queue.ranked
        }
      end)

    resp = Schema.response(cmd_id, message_id, %{playlists: queues}) |> Jason.encode!()

    {:reply, :ok, {:text, resp}, state}
  end

  def handle_command("matchmaking/queue" = cmd_id, "request", message_id, message, state) do
    queue_ids = message["data"]["queues"]

    response =
      case Player.Session.join_queues(state.user.id, queue_ids) do
        :ok ->
          Schema.response(cmd_id, message_id)

        {:error, reason} ->
          reason =
            case reason do
              :invalid_queue ->
                %{reason: :invalid_queue_specified}

              :too_many_players ->
                %{reason: :invalid_request, details: "too many player for a playlist"}

              x ->
                %{reason: x}
            end

          Map.merge(reason, %{
            type: :response,
            status: :failed,
            commandId: cmd_id,
            messageId: message_id
          })
      end

    {:push, {:text, Jason.encode!(response)}, state}
  end

  def handle_command("matchmaking/cancel" = cmd_id, "request", message_id, _message, state) do
    response =
      case Player.Session.leave_queues(state.user.id) do
        :ok ->
          Schema.response(cmd_id, message_id)

        {:error, reason} ->
          Schema.error_response(cmd_id, message_id, reason)
      end

    {:push, {:text, Jason.encode!(response)}, state}
  end

  def handle_command(command_id, _message_type, message_id, _message, state) do
    resp =
      Schema.error_response(command_id, message_id, :command_unimplemented)
      |> Jason.encode!()

    {:reply, :ok, {:text, resp}, state}
  end

  # Ensure a session is started for the given user id. Register both the session
  # and the connection. If a connection already exists, terminates it and
  # replace it in the player registry.
  # More work is required here, to seed the session with some initial
  # state. Because if the node holding the session process shuts down,
  # restarting the connection (through the supervisor) isn't enough.
  # The state associated with the connected player will not match
  # the brand new session.
  defp setup_session(user_id) do
    case Player.SessionSupervisor.start_session(user_id) do
      {:ok, _session_pid} ->
        Player.Registry.register_and_kill_existing(user_id)

      {:error, {:already_started, pid}} ->
        case Player.Session.replace_connection(pid, self()) do
          # This can happen when the session dies/terminate between the
          # start_session and the replace_connection. In which case, try again.
          # When a user disconnect and immediately reconnect it can happen
          # that the session is still registered
          :died ->
            setup_session(user_id)

          :ok ->
            Player.Registry.register_and_kill_existing(user_id)
        end
    end
  end
end
