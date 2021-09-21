defmodule Teiserver.Agents.AgentLib do
  alias Teiserver.Protocols.Tachyon
  alias Teiserver.User
  alias Teiserver.Account.UserCache
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
    {:ok, _supervisor_pid} =
      DynamicSupervisor.start_child(Teiserver.Agents.DynamicSupervisor, {
        Teiserver.Agents.SupervisorAgentServer,
        name: via_tuple(:supervisor),
        data: %{}
      })

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

  @spec via_tuple(integer() | :supervisor) :: {:via, Registry, {Teiserver.Agents.ServerRegistry, any}}
  @spec via_tuple(String.t(), integer()) :: {:via, Registry, {Teiserver.Agents.ServerRegistry, any}}
  def via_tuple(:supervisor) do
    via_tuple(Teiserver.Agents.SupervisorAgentServer, 1)
  end
  def via_tuple(id) do
    {:via, Registry, {Teiserver.Agents.ServerRegistry, id}}
  end
  def via_tuple(service, number) do
    via_tuple("#{service}-#{number}")
  end

  def get_socket() do
    {:ok, socket} =
      :ssl.connect(@localhost, Application.get_env(:central, Teiserver)[:ports][:tls], active: true)

    socket
  end

  defp do_login(socket, token) do
    msg = %{cmd: "c.auth.login", token: token, lobby_name: "agent_lobby", lobby_version: "1", lobby_hash: "token"}
    _send(socket, msg)
  end

  defp swap_to_tachyon(socket) do
    _send_raw(socket, "TACHYON\n")
    :timer.sleep(100)
    :ok
  end

  @spec login({:sslsocket, any, any}, Map.t()) :: :success
  def login(socket, data) do
    # If no user, make it
    if UserCache.get_user_by_email(data.email) == nil do
      User.register_user_with_md5(data.name, data.email, "password", "127.0.0.1")
      user = UserCache.get_user_by_name(data.name)
      user = %{user | verified: true, bot: data[:bot], moderator: data[:moderator]}
      UserCache.update_user(user, persist: true)
      UserCache.recache_user(user.id)
      :timer.sleep(100)
    end

    # Get the user
    user = UserCache.get_user_by_name(data.name)

    with :ok <- swap_to_tachyon(socket),
         token <- User.create_token(user),
         :ok <- do_login(socket, token)
      do
        {:success, user}
      else
        {:error, :login} -> throw "Login error"
    end
  end

  @spec _send({:sslsocket, any, any}, Map.t()) :: :ok
  def _send(socket = {:sslsocket, _, _}, data) do
    msg = Tachyon.encode(data) <> "\n"
    _send_raw(socket, msg)
  end

  @spec _send_raw({:sslsocket, any, any}, String.t()) :: :ok
  def _send_raw(socket = {:sslsocket, _, _}, msg) do
    :ok = :ssl.send(socket, msg)
  end

  def translate('OK cmd=TACHYON\n'), do: []
  def translate('TASSERVER 0.38-33-ga5f3b28 * 8201 0\n'), do: []
  def translate('TASSERVER 0.38-33-ga5f3b28 * 8201 0\nOK cmd=TACHYON\n'), do: []
  def translate(raw) do
    raw
    |> to_string
    |> String.split("\n")
    |> Enum.map(&do_translate/1)
    |> Enum.filter(fn r -> r != nil end)
  end

  defp do_translate(""), do: nil
  defp do_translate(line) do
    case Tachyon.decode!(line) do
      %{"cmd" => "s.auth.login"} -> nil
      msg -> msg
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
    # Logger.info("agent_updates - #{from} > #{msg}")
  end
end
