defmodule Teiserver.Tachyon.Transport do
  @moduledoc """
  Handle a tachyon connection
  This is the common behaviour for player, bot and whatever could pop up.
  It handle parsing and validating commands before delegating it to a handler
  """

  @behaviour WebSock
  require Logger
  alias Teiserver.Helpers.BurstyRateLimiter
  alias Teiserver.Tachyon.{Schema, Handler}

  @type connection_state() :: %{
          handler: term(),
          handler_state: term(),
          rate_limiter: BurstyRateLimiter.t() | nil,
          pending_responses: Handler.pending_responses()
        }

  @impl true
  def init(state) do
    # this is inside the process that maintain the connection
    schedule_ping()

    handle_result(
      state.handler.init(state.handler_state),
      Map.put(state, :pending_responses, %{})
    )
  end

  @doc """
  This is similar to GenServer.call but targets a tachyon client. It sends
  a request with the given command id and payload, then wait for a response
  from the client and returns it "synchronously"

  The code is heavily inspired from
  https://www.erlang.org/doc/apps/erts/erlang.html#monitor/3
  and
  :gen.call (https://github.com/erlang/otp/blob/OTP-28.0.2/lib/stdlib/src/gen.erl#L221-L227)
  """
  @spec call_client(pid(), Schema.command_id(), term(), timeout() | nil) :: term()
  def call_client(pid, cmd_id, payload, timeout \\ 5_000) when is_pid(pid) do
    req_id = Process.monitor(pid, alias: :reply_demonitor)
    send(pid, {:call_client, cmd_id, payload, req_id})

    receive do
      {^req_id, reply} ->
        Process.demonitor(req_id, [:flush])
        reply

      {:DOWN, ^req_id, _, _, :noconnection} ->
        node = node(pid)
        exit({{:nodedown, node}, {__MODULE__, :call_client, [pid, cmd_id, payload, timeout]}})

      {:DOWN, ^req_id, _, _, reason} ->
        exit({reason, {__MODULE__, :call_client, [pid, cmd_id, payload, timeout]}})
    after
      timeout ->
        Process.demonitor(req_id, [:flush])

        receive do
          {^req_id, reply} -> reply
        after
          0 -> exit({:timeout, {__MODULE__, :call_client, [pid, cmd_id, payload, timeout]}})
        end
    end
  end

  # for testing purpose only, to manipulate the state of the rate limiter
  @doc false
  def _test_rate_limiter_acquire(pid, n) do
    r = make_ref()
    send(pid, {:_rate_limiter_acquire, n, {self(), r}})

    receive do
      {:reply, ^r, result} -> result
    after
      5000 ->
        raise "timout"
    end
  end

  # dummy handle_in for now
  @impl true
  def handle_in({"test_ping\n", opcode: :text}, state) do
    # this is handy during manual test to ensure the connection is still alive
    {:reply, :ok, {:text, "test_pong"}, state}
  end

  def handle_in({"test_ping", opcode: :text}, state) do
    # this is handy during integration test to ensure the connection is still alive
    {:reply, :ok, {:text, "test_pong"}, state}
  end

  def handle_in({msg, opcode: :text}, state) do
    with {:ok, parsed} <- Jason.decode(msg),
         {:ok, command_id, message_type, message_id} <- Schema.parse_envelope(parsed),
         {:ok, rl} <- rate_limit(command_id, parsed, state.rate_limiter) do
      state = %{state | rate_limiter: rl}
      handle_command(command_id, message_type, message_id, parsed, state)
    else
      {:error, :request_too_big} ->
        {:stop, :normal, 1008, [{:text, "Request too big"}], state}

      {:error, to_wait} when is_number(to_wait) ->
        {:stop, :normal, 1008, [{:text, "Rate limited"}], state}

      {:error, err} ->
        {:stop, :normal, 1008, [{:text, "Invalid json sent #{inspect(err)}"}], state}
    end
  end

  def handle_in({_msg, opcode: :binary}, state) do
    {:stop, :normal, 1003, state}
  end

  @impl true
  def handle_info(:send_ping, state) do
    schedule_ping()
    {:push, {:ping, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}, state}
  end

  def handle_info(:force_disconnect, state) do
    # TODO: send a proper tachyon message to inform the client it is getting disconnected
    {:stop, :normal, state}
  end

  def handle_info({:timeout, message_id}, state) do
    {_, pendings} = Map.pop(state.pending_responses, message_id)

    {:stop, :timeout,
     {1008, "Response to request with message id #{message_id} not received in time."},
     %{state | pending_responses: pendings}}
  end

  def handle_info({:call_client, cmd_id, payload, req_id}, state) do
    opts = [cb_state: {:call_client_resp, req_id}]
    handle_result({:request, cmd_id, payload, opts, state.handler_state}, state)
  end

  def handle_info({:_rate_limiter_acquire, n, {from, r}}, state) do
    state =
      case state.rate_limiter do
        nil ->
          send(from, {:reply, r, nil})
          state

        rl ->
          result = BurstyRateLimiter.try_acquire(rl, n, :erlang.monotonic_time(:millisecond))

          state =
            case BurstyRateLimiter.try_acquire(rl, n, :erlang.monotonic_time(:millisecond)) do
              {:ok, rl} -> %{state | rate_limiter: rl}
              _ -> state
            end

          send(from, {:reply, r, result})
          state
      end

    {:ok, state}
  end

  def handle_info(msg, state) do
    handle_result(state.handler.handle_info(msg, state.handler_state), state)
  end

  @impl true
  def terminate(reason, state) do
    case reason do
      :normal ->
        nil

      :remote ->
        Logger.debug("Peer abruptly terminated connection #{inspect(state)}")

      {:error, :closed} ->
        Logger.debug("Peer closed connection #{inspect(state)}")

      {:crash, :error, err} ->
        Logger.error("ws connection crashed: #{inspect(err)}")

      _ ->
        Logger.info(
          "Terminating ws connection #{inspect(self())} with reason #{inspect(reason)} and state #{inspect(state)}"
        )
    end

    :ok
  end

  @spec handle_command(
          Schema.command_id(),
          Schema.message_type(),
          Schema.message_id(),
          term(),
          connection_state()
        ) ::
          WebSock.handle_result()
  def handle_command(command_id, message_type, message_id, message, state) do
    case Schema.parse_message(command_id, message_type, message) do
      :ok ->
        do_handle_command(command_id, message_type, message_id, message, state)

      {:missing_schema, command_id, _type} ->
        resp =
          Schema.error_response(command_id, message_id, :command_unimplemented)
          |> Jason.encode!()

        {:reply, :ok, {:text, resp}, state}

      {:error, %JsonXema.ValidationError{} = err} ->
        resp =
          Schema.error_response(command_id, message_id, :invalid_request, inspect(err))
          |> Jason.encode!()

        {:reply, :ok, {:text, resp}, state}

      {:error, err} ->
        resp =
          Schema.error_response(command_id, message_id, :internal_error, inspect(err))
          |> Jason.encode!()

        {:reply, :ok, {:text, resp}, state}
    end
  end

  def do_handle_command(command_id, "response", message_id, message, state) do
    case Map.pop(state.pending_responses, message_id) do
      # We got a response but nothing registered, which is invalid
      {nil, _} ->
        {:stop, :normal,
         {1008, "Received response to message id #{message_id} but no request pending."}, state}

      {{tref, cb_state}, new_pendings} ->
        :erlang.cancel_timer(tref)
        state = Map.replace!(state, :pending_responses, new_pendings)

        case cb_state do
          {:call_client_resp, req_id} ->
            send(req_id, {req_id, message})
            {:ok, state}

          cb_state ->
            if function_exported?(state.handler, :handle_response, 4) do
              result =
                state.handler.handle_response(command_id, cb_state, message, state.handler_state)

              handle_result(result, command_id, message_id, state)
            else
              {:ok, state}
            end
        end
    end
  end

  def do_handle_command(command_id, message_type, message_id, message, state) do
    start = :erlang.monotonic_time(:millisecond)

    result =
      state.handler.handle_command(
        command_id,
        message_type,
        message_id,
        message,
        state.handler_state
      )

    elapsed = :erlang.monotonic_time(:millisecond) - start

    response_details =
      case result do
        {:response, _} -> {:resp, :ok}
        {:response, _, _} -> {:resp, :ok}
        {:error_response, code, _} -> {:resp, code}
        {:error_response, code, _, _} -> {:resp, code}
        _ -> false
      end

    case response_details do
      {:resp, code} ->
        :telemetry.execute([:tachyon, :request], %{duration: elapsed, count: 1}, %{
          command_id: command_id,
          code: code
        })

      _ ->
        nil
    end

    try do
      handle_result(result, command_id, message_id, state)
    rescue
      e ->
        str_err = inspect({e, __STACKTRACE__})
        Logger.error([inspect(message), str_err])

        resp = Schema.error_response(command_id, message_id, :internal_error, str_err)
        {:push, {:text, Jason.encode!(resp)}, state}
    end
  end

  @spec handle_result(Handler.result(), connection_state()) ::
          WebSock.handle_result()
  defp handle_result(result, conn_state),
    do: handle_result(result, nil, nil, conn_state)

  # helper function to use the result from the invoked handler function
  @spec handle_result(
          Handler.result(),
          Schema.command_id() | nil,
          Schema.message_id() | nil,
          connection_state()
        ) ::
          WebSock.handle_result()
  defp handle_result(result, command_id, message_id, conn_state) do
    case result do
      {:event, evs, _} when is_list(evs) -> Enum.map(evs, fn {cmd_id, _} -> cmd_id end)
      {:event, cmd_id, _} -> [cmd_id]
      {:event, cmd_id, _payload, _} -> [cmd_id]
      _ -> []
    end
    |> Enum.each(fn cmd_id ->
      :telemetry.execute([:tachyon, :event], %{count: 1}, %{command_id: cmd_id})
    end)

    case result do
      {:event, events, state} when is_list(events) ->
        messages =
          Enum.map(events, fn {cmd_id, payload} ->
            msg = Schema.event(cmd_id, payload) |> Jason.encode!()
            {:text, msg}
          end)

        {:push, messages, %{conn_state | handler_state: state}}

      {:event, cmd_id, state} ->
        message = Schema.event(cmd_id) |> Jason.encode!()
        {:push, {:text, message}, %{conn_state | handler_state: state}}

      {:event, cmd_id, payload, state} ->
        message = Schema.event(cmd_id, payload) |> Jason.encode!()
        {:push, {:text, message}, %{conn_state | handler_state: state}}

      {:response, state} ->
        message = Schema.response(command_id, message_id)
        {:push, {:text, Jason.encode!(message)}, %{conn_state | handler_state: state}}

      {:response, {resp_payload, events}, state} ->
        resp = {:text, Schema.response(command_id, message_id, resp_payload) |> Jason.encode!()}
        messages = Enum.map(events, fn ev -> {:text, ev |> Jason.encode!()} end)
        {:push, [resp | messages], %{conn_state | handler_state: state}}

      {:response, payload, state} ->
        message = Schema.response(command_id, message_id, payload)
        {:push, {:text, Jason.encode!(message)}, %{conn_state | handler_state: state}}

      {:error_response, reason, state} ->
        message = Schema.error_response(command_id, message_id, reason)
        {:push, {:text, Jason.encode!(message)}, %{conn_state | handler_state: state}}

      {:error_response, reason, details, state} ->
        message = Schema.error_response(command_id, message_id, reason, details)
        {:push, {:text, Jason.encode!(message)}, %{conn_state | handler_state: state}}

      {:request, cmd_id, payload, opts, state} ->
        req = Schema.request(cmd_id, payload)

        message_id = req.messageId
        timeout = Keyword.get(opts, :timeout, :timer.seconds(10_000))
        tref = :erlang.send_after(timeout, self(), {:timeout, message_id})

        new_state =
          conn_state
          |> Map.update(:pending_responses, %{}, fn pendings ->
            Map.put(pendings, message_id, {tref, opts[:cb_state]})
          end)
          |> Map.put(:handler_state, state)

        {:push, {:text, Jason.encode!(req)}, new_state}

      # then the websock result
      {:push, messages, state} ->
        {:push, messages, %{conn_state | handler_state: state}}

      {:reply, term, messages, state} ->
        {:reply, term, messages, %{conn_state | handler_state: state}}

      {:ok, state} ->
        {:ok, %{conn_state | handler_state: state}}

      {:stop, reason, state} ->
        {:stop, reason, %{conn_state | handler_state: state}}

      {:stop, reason, close_details, state} ->
        {:stop, reason, close_details, %{conn_state | handler_state: state}}

      {:stop, reason, close_details, messages, state} ->
        {:stop, reason, close_details, messages, %{conn_state | handler_state: state}}
    end
  end

  defp rate_limit(_command_id, _parsed, nil), do: {:ok, nil}

  defp rate_limit(_command_id, _parsed, rl) do
    cost = 1
    BurstyRateLimiter.try_acquire(rl, cost, :erlang.monotonic_time(:millisecond))
  end

  defp schedule_ping() do
    # we want a ping/pong every 10s and avoid thundering herd
    wait = 1_000 + :rand.uniform(8500)
    :timer.send_after(wait, :send_ping)
  end
end
