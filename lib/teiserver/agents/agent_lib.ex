defmodule Teiserver.Agents.AgentLib do
  alias Teiserver.User
  alias Phoenix.PubSub
  require Logger

  @localhost '127.0.0.1'

  @spec icon() :: String.t()
  def icon(), do: "far fa-user-robot"

  @spec do_start() :: :ok
  defp do_start() do
    children = [
      # Benchmark stuff
      {Registry, keys: :unique, name: Teiserver.Agents.ServerRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Agents.DynamicSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Teiserver.Agents.Supervisor]
    Supervisor.start_link(children, opts)

    # Start the supervisor server
    {:ok, supervisor_pid} =
        DynamicSupervisor.start_child(Teiserver.Agents.DynamicSupervisor, {
          Teiserver.Agents.SupervisorServer,
          name: via_tuple(:supervisor),
          data: %{}
        })

    send(supervisor_pid, :begin)
    :ok
  end

  @spec start() :: :ok | :failure
  def start() do
    case Application.get_env(:central, Teiserver)[:enable_agent_mode] do
      true ->
        do_start()
        :ok
      false ->
        :failure
    end
  end

  def via_tuple(:supervisor) do
    via_tuple(Teiserver.Agents.SupervisorServer, 1)
  end
  def via_tuple(id) do
    {:via, Registry, {Teiserver.Agents.ServerRegistry, id}}
  end
  def via_tuple(service, number) do
    via_tuple("#{service}-#{number}")
  end

  def get_socket() do
    {:ok, socket} =
      :ssl.connect(@localhost, Application.get_env(:central, Teiserver)[:ports][:tls], active: false)
    _ = _recv(socket)

    socket
  end

  @spec login(:sslsocket, Map.t()) :: :ok | :failure
  def login(socket, data) do
    exists = cond do
      User.get_user_by_name(data.name) ->
        true

      User.get_user_by_email(data.email) ->
        true

      true ->
        false
    end

    # If no user, make it
    if not exists do
      User.register_user_with_md5(data.name, data.email, "password", "127.0.0.1")
      user = User.get_user_by_name(data.name)
      user = %{user | verified: true}
      User.update_user(user, persist: true)
    end

    # Get the user
    user = User.get_user_by_name(data.name)

    # Get token
    _send(socket, "c.user.get_token_by_email #{user.email}\tpassword\n")
    reply = _recv(socket, 1500)
    token =
      String.replace(reply, "s.user.user_token #{user.email}\t", "")
      |> String.replace("\n", "")

    # Perform login
    _send(socket, "c.user.login #{token}\tLobby Name\n")
    reply = _recv(socket)
    expected_reply = "ACCEPTED #{user.name}\n"

    case reply == expected_reply do
      true -> :ok
      false -> :failure
    end
  end

  @spec _send({:sslsocket, any, any}, String.t()) :: :ok
  def _send(socket = {:sslsocket, _, _}, msg) do
    :ok = :ssl.send(socket, msg)
  end

  @spec _recv({:sslsocket, any, any}) :: String.t() | :timeout | :closed
  def _recv(socket = {:sslsocket, _, _}, timeout \\ 500) do
    case :ssl.recv(socket, 0, timeout) do
      {:ok, reply} -> reply |> to_string
      {:error, :timeout} -> :timeout
      {:error, :closed} -> :closed
    end
  end

  @spec post_agent_update(any) :: :ok
  def post_agent_update(data) do
    PubSub.broadcast(
      Central.PubSub,
      "agent_updates",
      data
    )
    Logger.info("agent_updates - #{Kernel.inspect(data)}")
  end
end
