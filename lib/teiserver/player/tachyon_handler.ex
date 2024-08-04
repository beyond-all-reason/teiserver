defmodule Teiserver.Player.TachyonHandler do
  @moduledoc """
  Player specific code to handle tachyon logins and actions
  """

  alias Teiserver.Tachyon.Handler
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Player

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
  def handle_info(_msg, state) do
    {:ok, state}
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
        :ok = Player.Session.replace_connection(pid, self())
        Player.Registry.register_and_kill_existing(user_id)
    end
  end
end
