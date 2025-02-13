defmodule Teiserver.Autohost.TachyonHandler do
  @moduledoc """
  Handle a connection with an autohost using the tachyon protocol.

  This is treated separately from a player connection because they fulfill
  very different roles, have very different behaviour and states.
  """
  alias Teiserver.Tachyon.{Handler, Schema}
  alias Teiserver.Autohost.Registry
  alias Teiserver.Bot.Bot
  require Logger
  @behaviour Handler

  @type connected_state :: %{max_battles: non_neg_integer(), current_battles: non_neg_integer()}
  @type state :: %{
          autohost: Bot.t(),
          state: :handshaking | {:connected, connected_state()},
          pending_responses: Handler.pending_responses()
        }

  @type start_response :: %{
          ips: [String.t()],
          port: integer(),
          engine: %{version: String.t()},
          game: %{springName: String.t()},
          map: %{springName: String.t()}
        }

  @impl Handler
  def connect(conn) do
    autohost = conn.assigns[:token].bot
    {:ok, %{autohost: autohost, state: :handshaking, pending_responses: %{}}}
  end

  @impl Handler
  @spec init(state()) :: WebSock.handle_result()
  def init(state) do
    {:ok, state}
  end

  @impl Handler
  def handle_info({:start_battle, start_script, sender}, state) do
    {:request, "autohost/start", start_script, [cb_state: sender], state}
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
    {:stop, :normal, state}
  end

  def handle_command("autohost/status", "event", _msg_id, msg, %{state: :handshaking} = state) do
    %{"data" => %{"maxBattles" => max_battles, "currentBattles" => current}} = msg

    Logger.info(
      "Autohost (id=#{state.autohost.id}) connecting #{state.autohost.id} with #{inspect(msg["data"])}"
    )

    state = %{
      state
      | state:
          {:connected,
           %{
             max_battles: max_battles,
             current_battles: current
           }}
    }

    case Registry.register(%{
           id: state.autohost.id,
           max_battles: max_battles,
           current_battles: current
         }) do
      {:error, {:already_registered, _pid}} ->
        # TODO: maybe we should handle that by disconnecting the existing one?
        {:stop, :normal, state}

      _ ->
        {:ok, state}
    end
  end

  def handle_command("autohost/status", "event", _, msg, state) do
    %{"data" => %{"maxBattles" => max_battles, "currentBattles" => current}} = msg

    Registry.update_value(state.autohost.id, fn _ ->
      %{id: state.autohost.id, max_battles: max_battles, current_battles: current}
    end)

    state = %{state | state: {:connected, %{max_battles: max_battles, current_battles: current}}}
    {:ok, state}
  end

  def handle_command(
        command_id,
        _message_type,
        message_id,
        _message,
        %{state: :handshaking} = state
      ) do
    resp =
      Schema.error_response(
        command_id,
        message_id,
        :invalid_request,
        "The first message after connection must be `status`"
      )
      |> Jason.encode!()

    # 1000 = close normal
    {:stop, :normal, 1000, [{:text, resp}], state}
  end

  def handle_command(command_id, _message_type, message_id, _message, state) do
    resp =
      Schema.error_response(command_id, message_id, :command_unimplemented)
      |> Jason.encode!()

    {:reply, :ok, {:text, resp}, state}
  end

  @impl true
  def handle_response("autohost/start", reply_to, response, state) do
    notify_autohost_started(reply_to, response)
    {:ok, state}
  end

  # TODO: there should be some kind of retry here
  @spec start_battle(Bot.id(), Teiserver.Autohost.start_script()) ::
          {:ok, start_response()} | {:error, term()}
  def start_battle(autohost_id, start_script) do
    case Registry.lookup(autohost_id) do
      {pid, _} ->
        send(pid, {:start_battle, start_script, self()})

        # This receive is a bit iffy and may cause problem with controlled shutdown
        # Ideally, the same way player work, there would be a GenServer decoupled
        # from the actual websocket connection, but for now, this poor's man
        # GenServer.call will have to do
        receive do
          {:start_battle_response, resp} -> resp
        after
          10_000 -> {:error, :timeout}
        end

      _ ->
        {:error, :no_host_available}
    end
  end

  defp notify_autohost_started(reply_to, %{"status" => "failed", "reason" => reason} = msg) do
    msg =
      case msg["details"] do
        nil -> reason
        details -> "#{reason} - #{details}"
      end

    send(reply_to, {:start_battle_response, {:error, msg}})
  end

  defp notify_autohost_started(reply_to, %{"status" => "success", "data" => data}) do
    send(
      reply_to,
      {:start_battle_response,
       {:ok,
        %{
          ips: data["ips"],
          port: data["port"]
        }}}
    )
  end
end
