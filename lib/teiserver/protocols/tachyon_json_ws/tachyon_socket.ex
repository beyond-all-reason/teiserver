defmodule Tachyon.TachyonSocket do
  @behaviour Phoenix.Socket.Transport

  require Logger
  alias Phoenix.PubSub
  alias Central.Config
  alias Teiserver.Account
  alias Teiserver.Tachyon.{CommandDispatch}
  alias Teiserver.Data.Types, as: T

  @type ws_state() :: map()

  def validate_schemas() do
    (
      "priv/tachyon/v1.json"
      |> File.read!
      |> Jason.decode!
      |> Enum.each(fn json_def ->
        schema = ExJsonSchema.Schema.resolve(json_def)
        Central.store_put(:tachyon_schemas, json_def["$id"], schema)
      end)
    )
  end

  @spec child_spec(any) :: any()
  def child_spec(_opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @spec connect(ws_state()) :: {:ok, ws_state()}
  def connect(%{params: %{"token" => token}} = state) do
    case Account.get_user_token_by_value(token) do
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

  # Example of a good whoami request
  # {"command": "account/who_am_i/request", "data": {}}

  # @spec handle_in({atom, any}, ws_state()) :: {:ok, ws_state()} | {:reply, :ok, {:text, String.t()}, ws_state()}
  def handle_in({text, _opts}, %{conn: conn} = state) do
    with {:ok, raw_json} <- decompress_message(text, conn),
      {:ok, wrapped_object} <- decode_message(raw_json, conn),
      {:ok, resp, new_conn} <- handle_command(wrapped_object, conn)
      do
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
      {:error, err} -> {:json_error, "Decode error: #{inspect err}"}
    end
  end

  defp handle_command(wrapper, conn) do
    object = wrapper["data"]
    meta = Map.drop(wrapper, ["data"])

    resp = CommandDispatch.dispatch(conn, object, meta)

    IO.puts ""
    IO.inspect resp
    IO.puts ""

    {:ok, %{}, conn}
  end

  defp make_resp(user) do
    %{
      "id" => user.id,
      "name" => user.name,
      "is_bot" => user.bot,
      "clan_id" => user.clan_id,
      "icons" => %{},
      "roles" => [],

      "battle_status" => %{
        "in_game" => false,
        "away" => false,
        "ready" => false,
        "player_number" => 1,
        "team_colour" => "colour",
        "is_player" => false,
        "bonus" => 0,
        "sync" => %{},
        "faction" => "cortex",
        "lobby_id" => 123,
        "party_id" => 123,
        "clan_tag" => "xyz",
        "muted" => false
      },

      "permissions" => [],
      "friends" => [],
      "friend_requests" => [],
      "ignores" => []
    }
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
