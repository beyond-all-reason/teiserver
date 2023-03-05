defmodule Tachyon.TachyonSocket do
  @behaviour Phoenix.Socket.Transport

  require Logger
  alias Phoenix.PubSub
  alias Central.Config
  alias Teiserver.Tachyon.{TachyonPbLib, ClientDispatcher}
  alias Teiserver.Protocols.Tachyon.TachyonProtobufIn
  alias Teiserver.Data.Types, as: T

  @type ws_state() :: map()

  @spec child_spec(any) :: any()
  def child_spec(_opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @spec connect(ws_state()) :: {:ok, ws_state()}
  def connect(%{params: %{"token" => token}} = state) do
    case Central.Account.get_user_token_by_value(token) do
      nil ->
        :error

      %{user: user, expires: expires} ->
        if expires == nil or Timex.compare(expires, Timex.now) == 1 do
          {:ok, Map.put(state, :conn, new_state(user))}
        else
          :error
        end
    end
  end
  def connect(_state) do
    :error
  end

  @spec init(ws_state()) :: {:ok, ws_state()}
  def init(state) do
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_server")

    {:ok, state}
  end

  @spec handle_in({atom, any}, ws_state()) :: {:reply, :ok, {:binary, binary}, ws_state()}
  def handle_in({text, _opts}, %{conn: conn} = state) do
    {result_type, result_object, metadata, conn_updates} = TachyonProtobufIn.handle(text, conn)

    new_conn = if conn_updates do
      Map.merge(conn, conn_updates)
    else
      conn
    end

    resp = TachyonPbLib.server_wrap_and_encode({result_type, result_object}, metadata)
    Logger.debug("WS out: " <> inspect_object(result_object))

    {:reply, :ok, {:binary, resp}, %{state | conn: new_conn}}
  end

  @spec handle_info(any, ws_state()) :: {:reply, :ok, {:binary, binary}, ws_state()}
  def handle_info(_msg, state) do
    # IO.puts ""
    # IO.inspect msg, label: "ws handle_info"
    # IO.puts ""

    # {:ok, state}
    {:reply, :ok, {:binary, <<111>>}, state}
  end

  @spec terminate(any, any) :: :ok
  def terminate(_reason, _state) do
    :ok
  end

  @spec new_state(Central.Account.User.t()) :: map()
  defp new_state(user) do
    %{
      # Client state
      userid: user.id,
      lobby_host: false,
      queues: [],
      lobby_id: nil,
      party_id: nil,
      party_role: nil,
      exempt_from_cmd_throttle: true,
      cmd_timestamps: [],

      # Caching app configs
      flood_rate_limit_count: Config.get_site_config_cache("teiserver.Tachyon flood rate limit count"),
      floot_rate_window_size: Config.get_site_config_cache("teiserver.Tachyon flood rate window size")
    }
  end

  defp inspect_object(object) do
    object
      |> Map.drop([:__unknown_fields__])
      |> inspect
  end
end
