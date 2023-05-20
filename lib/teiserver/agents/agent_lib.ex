defmodule Teiserver.Agents.AgentLib do
  alias Teiserver.Protocols.TachyonLib
  alias Teiserver.User
  alias Phoenix.PubSub
  require Logger
  alias Teiserver.Data.Types, as: T

  @localhost '127.0.0.1'

  @spec colours :: atom
  def colours(), do: :danger

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-user-robot"

  @spec do_start() :: :ok
  defp do_start() do
    # Start the supervisor server
    {:ok, _supervisor_pid} =
      DynamicSupervisor.start_child(Teiserver.Agents.DynamicSupervisor, {
        Teiserver.Agents.SupervisorAgentServer,
        name: via_tuple(:supervisor), data: %{}
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

  @spec via_tuple(integer() | :supervisor) ::
          {:via, Registry, {Teiserver.Agents.ServerRegistry, any}}
  @spec via_tuple(String.t(), integer()) ::
          {:via, Registry, {Teiserver.Agents.ServerRegistry, any}}
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
      :ssl.connect(@localhost, Application.get_env(:central, Teiserver)[:ports][:tachyon],
        active: true,
        verify: :verify_none
      )

    socket
  end

  defp do_login(socket, token) do
    msg = %{
      cmd: "c.auth.login",
      token: token,
      lobby_name: "agent_lobby",
      lobby_version: "1",
      lobby_hash: "token1 token2"
    }

    _send(socket, msg)
  end

  @spec login({:sslsocket, any, any}, Map.t()) :: {:success, T.user()}
  def login(socket, data) do
    # If no user, make it
    if User.get_user_by_email(data.email) == nil do
      case User.register_user_with_md5(data.name, data.email, "password", "127.0.0.1") do
        :success ->
          user = User.get_user_by_name(data.name)
          user = %{user | bot: data[:bot], moderator: data[:moderator]}
          User.update_user(user, persist: true)
          User.recache_user(user.id)
          :timer.sleep(100)

        {:error, error_message} ->
          raise "Login error - #{error_message}, name: #{data.name}"
      end
    end

    user = User.get_user_by_name(data.name)

    with token <- User.create_token(user),
         :ok <- do_login(socket, token) do
      {:success, user}
    else
      {:error, :login} ->
        raise "Login error"
    end
  end

  @spec _send({:sslsocket, any, any}, Map.t()) :: :ok
  def _send(socket = {:sslsocket, _, _}, data) do
    msg = TachyonLib.encode(data) <> "\n"
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
    case TachyonLib.decode!(line) do
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
