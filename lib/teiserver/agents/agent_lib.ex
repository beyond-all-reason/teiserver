defmodule Teiserver.Agents.AgentLib do
  alias Teiserver.Protocols.Tachyon
  alias Teiserver.User
  alias Phoenix.PubSub
  require Logger

  @localhost '127.0.0.1'

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Helpers.StylingHelper.colours(:danger)

  @spec icon() :: String.t()
  def icon(), do: "far fa-user-robot"

  @spec do_start() :: :ok
  defp do_start() do
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

  @spec start() :: :ok | {:failure, String.t()}
  def start() do
    cond do
      Application.get_env(:central, Teiserver)[:enable_agent_mode] != true ->
        {:failure, "Agent mode not active"}

      Supervisor.count_children(Teiserver.Agents.DynamicSupervisor)[:active] > 0 ->
        {:failure, "Already started"}

      true ->
        do_start()
        :ok
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
    _ = _recv_raw(socket)

    socket
  end

  defp do_login(socket, token, user) do
    msg = %{cmd: "c.auth.login", token: token, lobby_name: "agent_lobby", lobby_version: "1"}
    _send(socket, msg)
    reply = _recv(socket)

    IO.puts "reply"
    IO.inspect reply
    IO.puts ""


    if reply == "ACCEPTED #{user.name}\n" do
      _welcome_msg = _recv(socket)
      :ok
    else
      {:error, :login}
    end
  end

  defp swap_to_tachyon(socket) do
    _send_raw(socket, "TACHYON\n")
    reply = _recv_raw(socket)

    if reply == "OK cmd=TACHYON\n" do
      :ok
    else
      {:error, :login}
    end
  end

  @spec login({:sslsocket, any, any}, Map.t()) :: :ok | :failure
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
    _welcome_msg = _recv(socket)

    with :ok <- swap_to_tachyon(socket),
         token <- User.create_token(user),
         :ok <- do_login(socket, token, user)
      do
        :success
      else
        {:error, :login} -> throw "Login error"
    end
  end

  @spec _send_raw({:sslsocket, any, any}, Map.t()) :: :ok
  def _send(socket = {:sslsocket, _, _}, data) do
    msg = Tachyon.encode(data)
    _send_raw(socket, msg <> "\n")
  end

  @spec _send_raw({:sslsocket, any, any}, String.t()) :: :ok
  def _send_raw(socket = {:sslsocket, _, _}, msg) do
    :ok = :ssl.send(socket, msg)
  end


  @spec _recv({:sslsocket, any, any}) :: String.t() | :timeout | :closed
  def _recv(socket = {:sslsocket, _, _}, timeout \\ 500) do
    case _recv_raw(socket, timeout) do
      :timeout ->
        :timeout

      resp ->
        Tachyon.decode!(resp)
    end
  end

  @spec _recv_raw({:sslsocket, any, any}) :: String.t() | :timeout | :closed
  def _recv_raw(socket = {:sslsocket, _, _}, timeout \\ 500) do
    case :ssl.recv(socket, 0, timeout) do
      {:ok, reply} -> reply |> to_string
      {:error, :timeout} -> :timeout
      {:error, :closed} -> :closed
    end
  end

  @spec post_agent_update(String.t(), String.t(), Map.t()) :: :ok
  def post_agent_update(from, msg, data \\ %{}) do
    PubSub.broadcast(
      Central.PubSub,
      "agent_updates",
      %{
        from: from,
        msg: msg,
        data: data
      }
    )
    Logger.info("agent_updates - #{from} > #{msg}")
  end
end
