defmodule Tachyon.TachyonSocket do
  @behaviour Phoenix.Socket.Transport

  require Logger
  alias Phoenix.PubSub
  alias Central.Config
  alias Teiserver.Account
  alias Teiserver.Tachyon.{CommandDispatch}
  alias Teiserver.Data.Types, as: T

  @type ws_state() :: map()

  @spec child_spec(any) :: any()
  def child_spec(_opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @spec connect(ws_state()) :: {:ok, ws_state()}
  def connect(
        %{params: %{"token" => token_value, "client_hash" => _, "client_name" => _}} = state
      ) do
    case Account.get_user_token_by_value(token_value) do
      nil ->
        :error

      %{user: _user, expires: _expires} = token ->
        case login(token, state) do
          {:ok, conn} ->
            {:ok, Map.put(state, :conn, conn)}

          _ ->
            :error
        end

      value ->
        Logger.error(
          "Error at: #{__ENV__.file}:#{__ENV__.line} - No handler for value of #{inspect(value)}"
        )

        :error
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

  # Example of a good whoami request
  # {"command": "account/who_am_i/request", "data": {}}

  # @spec handle_in({atom, any}, ws_state()) :: {:ok, ws_state()} | {:reply, :ok, {:text, String.t()}, ws_state()}
  def handle_in({text, _opts}, %{conn: conn} = state) do
    with {:ok, raw_json} <- decompress_message(text, conn),
         {:ok, wrapped_object} <- decode_message(raw_json, conn),
         {:ok, resp, new_conn} <- handle_command(wrapped_object, conn) do
      if resp != nil do
        {:reply, :ok, {:text, resp |> Jason.encode!()}, %{state | conn: new_conn}}
      else
        {:ok, state}
      end
    else
      {:json_error, error_message} ->
        {:reply, :ok, {:text, %{error: error_message} |> Jason.encode!()}, state}
    end
  end

  defp decompress_message(text, _conn) do
    {:ok, text}
  end

  defp decode_message(text, _conn) do
    case Jason.decode(text) do
      {:ok, msg} -> {:ok, msg}
      {:error, err} -> {:json_error, "Decode error: #{inspect(err)}"}
    end
  end

  defp handle_command(wrapper, conn) do
    object = wrapper["data"]
    meta = Map.drop(wrapper, ["data"])

    {command, data, new_conn} = CommandDispatch.dispatch(conn, object, meta)

    response = %{
      "command" => command,
      "data" => data
    }

    Teiserver.Tachyon.Schema.validate!(response)

    {:ok, response, new_conn}
  end

  @spec handle_info(any, ws_state()) :: {:reply, :ok, {:binary, binary}, ws_state()}
  def handle_info(:disconnect, state) do
    {:stop, :disconnected, state}
  end

  def handle_info(msg, state) do
    IO.puts("")
    IO.inspect(msg, label: "ws handle_info")
    IO.puts("")

    # Use this to not send anything
    {:ok, state}

    # This will send stuff
    # {:reply, :ok, {:binary, <<111>>}, state}
  end

  @spec terminate(any, any) :: :ok
  def terminate(_reason, %{conn: conn} = _state) do
    Teiserver.Client.disconnect(conn.userid, "ws_error terminate")
    :ok
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp login(%{user: user, expires: expires} = token, state) do
    response = Teiserver.User.login_from_token(token, state)

    case response do
      {:ok, logged_in_user} ->
        {:ok, new_conn(logged_in_user)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec new_conn(Central.Account.User.t()) :: map()
  defp new_conn(user) do
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
      flood_rate_limit_count:
        Config.get_site_config_cache("teiserver.Tachyon flood rate limit count"),
      floot_rate_window_size:
        Config.get_site_config_cache("teiserver.Tachyon flood rate window size")
    }
  end

  defp inspect_object(object) do
    object
    |> Map.drop([:__unknown_fields__])
    |> inspect
  end
end
