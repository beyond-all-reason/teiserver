defmodule Teiserver.Tachyon.TachyonSocket do
  @behaviour Phoenix.Socket.Transport

  require Logger
  alias Phoenix.PubSub
  alias Central.Config
  alias Teiserver.Account
  alias Teiserver.Tachyon.{CommandDispatch, MessageHandlers}
  # alias Teiserver.Data.Types, as: T

  @type ws_state() :: map()

  @spec child_spec(any) :: any()
  def child_spec(_opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @spec connect(ws_state()) :: {:ok, ws_state()} | :error
  def connect(
        %{params: %{
          "token" => token_value,
          "application_hash" => _,
          "application_name" => _,
          "application_version" => _
          }} = state
      ) do
    case Account.get_user_token_by_value(token_value) do
      nil ->
        {:error, :no_user}

      %{user: _user, expires: _expires} = token ->
        case login(token, state) do
          {:ok, conn} ->
            {:ok, Map.put(state, :conn, conn)}

          v ->
            Logger.error("Error at: #{__ENV__.file}:#{__ENV__.line} - Login failure with token: #{inspect v}\n")
            {:error, :failed_login}
        end

      value ->
        Logger.error(
          "Error at: #{__ENV__.file}:#{__ENV__.line} - No handler for value of #{inspect(value)}"
        )

        {:error, :unexpected_value}
    end
  end

  def connect(%{params: params}) do
    missing = ~w(token application_hash application_name application_version)
      |> Enum.reject(fn key -> Map.has_key?(params, key) end)
      |> Enum.join(", ")

    {:error, {:missing_params, missing}}
  end

  @spec init(ws_state()) :: {:ok, ws_state()}
  def init(state) do
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_server")

    {:ok, state}
  end

  # Example of a good whoami request
  # {"command": "account/whoAmI/request", "data": {}}

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

    {dispatch_response, new_conn} = CommandDispatch.dispatch(conn, object, meta)

    response = case dispatch_response do
      {command, :success, nil} ->
        nil

      {command, :success, data} ->
        %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

      {command, :error, reason} ->
        %{
          "command" => command,
          "status" => "failure",
          "reason" => reason
        }

      # These two predate the latest error response method, remove them if no longer needed
      {command, {:error, reason}, nil} ->
        %{
          "command" => command,
          "status" => "failure",
          "reason" => reason
        }

      {command, {:error, reason}, data} ->
        %{
          "command" => command,
          "status" => "failure",
          "reason" => reason,
          "data" => data
        }
    end

    # Currently not able to validate errors so leaving it out
    if response != nil do
      Teiserver.Tachyon.Schema.validate!(response)
    end

    {:ok, response, new_conn}
  end

  @spec handle_info(any, ws_state()) :: {:reply, :ok, {:binary, binary}, ws_state()}
  # def handle_info(%{channel: "teiserver_lobby_host_message:" <> _} = msg, state) do
  #   case MessageHandlers.LobbyHostMessageHandlers.handle(msg, state) do
  #     nil ->
  #       {:ok, state}

  #     {:ok, new_state} ->
  #       {:ok, new_state}

  #     {:ok, resp, new_state} ->
  #       {:reply, :ok, {:text, resp |> Jason.encode!()}, new_state}
  #   end
  # end

  def handle_info(%{} = msg, state) do
    IO.puts("")
    IO.inspect(msg, label: "ws handle_info")
    IO.puts("")

    # Use this to not send anything
    {:ok, state}

    # This will send stuff
    # {:reply, :ok, {:binary, <<111>>}, state}
  end

  def handle_info(:disconnect, state) do
    {:stop, :disconnected, state}
  end

  @spec terminate(any, any) :: :ok
  def terminate({:error, :closed}, %{conn: %{userid: userid}} = _state) do
    Teiserver.Client.disconnect(userid, "connection closed by client")
    :ok
  end

  def terminate(reason, %{conn: %{userid: userid}} = _state) do
    Teiserver.Client.disconnect(userid, "ws terminate - reason: #{inspect(reason)}")
    :ok
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp login(%{user: _user, expires: _expires} = token, state) do
    response = Teiserver.User.login_from_token(token, state)

    case response do
      {:ok, user} ->
        {:ok, new_conn(user)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec new_conn(Central.Account.User.t()) :: map()
  defp new_conn(user) do
    # exempt_from_cmd_throttle = user.moderator == true or User.is_bot?(user) == true
    exempt_from_cmd_throttle = true

    Logger.metadata(request_id: "TachyonWSServer##{user.id}")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{user.id}")

    IO.puts ""
    IO.inspect "teiserver_client_messages:#{user.id}", label: "Subbing"
    IO.puts ""

    %{
      # Client state
      userid: user.id,
      lobby_host: false,
      queues: [],
      lobby_id: nil,
      party_id: nil,
      party_role: nil,
      exempt_from_cmd_throttle: exempt_from_cmd_throttle,
      cmd_timestamps: [],

      # Caching app configs
      flood_rate_limit_count:
        Config.get_site_config_cache("teiserver.Tachyon flood rate limit count"),
      floot_rate_window_size:
        Config.get_site_config_cache("teiserver.Tachyon flood rate window size")
    }
  end

  def handle_error(conn, {:missing_params, param}), do: Plug.Conn.send_resp(conn, 400, "Missing parameter(s): #{param}")
  def handle_error(conn, :no_user), do: Plug.Conn.send_resp(conn, 401, "Unauthorized")
  def handle_error(conn, :failed_login), do: Plug.Conn.send_resp(conn, 403, "Forbidden")
  def handle_error(conn, :rate_limit), do: Plug.Conn.send_resp(conn, 429, "Too many requests")

  def handle_error(conn, :unexpected_value), do: Plug.Conn.send_resp(conn, 500, "Internal server error")
end
