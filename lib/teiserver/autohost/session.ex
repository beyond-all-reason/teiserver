defmodule Teiserver.Autohost.Session do
  @moduledoc """
  Similar to player's session, this is a process tied to a autohost connection
  in such a way that it survives if the connection goes away, and can be
  cleanly shutdown when required.
  """

  alias Teiserver.Autohost
  alias Teiserver.Autohost.SessionRegistry
  alias Teiserver.Autohost.TachyonHandler
  alias Teiserver.Bot.Bot
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.TachyonBattle

  require Logger

  @behaviour :gen_statem

  @default_call_timeout 5000

  @typep battle_data :: %{
           start_script: Autohost.start_script(),
           ips: [String.t()],
           port: non_neg_integer(),
           # it is guaranteed that the event timestamp is unique per battle
           pending_acks: :queue.queue(time: DateTime.t()),
           last_acked_ts: DateTime.t() | nil
         }

  @typep data :: %{
           autohost: Bot.t(),
           conn_pid: pid(),
           monitors: MC.t(),
           max_battles: non_neg_integer(),
           current_battles: non_neg_integer(),
           pending_battles: %{TachyonBattle.id() => {GenServer.from(), Autohost.start_script()}},
           active_battles: %{TachyonBattle.id() => battle_data()},
           pending_replies: %{reference() => GenServer.from()}
         }

  @typep state :: :handshaking | :connected

  def child_spec({autohost, _conn_pid} = args) do
    %{
      id: via_tuple(autohost.id),
      start: {__MODULE__, :start_link, [args]},
      restart: :temporary
    }
  end

  def start_link({autohost, _conn_pid} = arg) do
    autohost.id |> via_tuple() |> :gen_statem.start_link(__MODULE__, arg, [])
  end

  @impl :gen_statem
  def callback_mode, do: :handle_event_function

  @type start_response :: %{ips: [String.t()], port: integer()}

  # TODO: there should be some kind of retry here
  @spec start_battle(Bot.id(), TachyonBattle.id(), pid(), Autohost.start_script()) ::
          {:ok, autohost_pid :: pid(), start_response()} | {:error, term()}
  def start_battle(autohost_id, battle_id, battle_pid, start_script) do
    autohost_id
    |> via_tuple()
    |> :gen_statem.call(
      {:start_battle, battle_id, battle_pid, start_script},
      @default_call_timeout
    )
  catch
    :exit, {:noproc, _details} -> {:error, :no_host_available}
  end

  @doc """
  Meant for the tachyon handler to notify back the session that it got the
  response to autohost/start
  """
  @spec reply_start_battle(
          pid(),
          TachyonBattle.id(),
          {:ok, start_response()} | {:error, term()}
        ) :: :ok

  def reply_start_battle(session_pid, battle_id, resp) do
    send(session_pid, {:reply_start_battle, battle_id, resp})
  end

  @doc """
  send a message to the autohost with the given id
  this calls returns when the ack to the request has been received.
  """
  @spec send_message(Bot.id(), %{battle_id: TachyonBattle.id(), message: String.t()}) ::
          :ok | {:error, reason :: term()}
  def send_message(autohost_id, payload) do
    autohost_id
    |> via_tuple()
    |> :gen_statem.call({:send_message, payload}, @default_call_timeout)
  catch
    :exit, {:noproc, _details} -> {:error, :no_autohost}
  end

  @spec reply_send_message(pid(), reference(), :ok | {:error, reason :: term()}) :: :ok
  def reply_send_message(session_pid, ref, resp) do
    send(session_pid, {:reply_send_message, ref, resp})
  end

  @doc """
  to track how many battles the autohost can handle
  """
  @spec update_capacity(pid(), non_neg_integer(), non_neg_integer()) :: :ok
  def update_capacity(session_pid, max_battles, current_battles) do
    send(session_pid, {:update_capacity, max_battles, current_battles})
  end

  @spec handle_update_event(pid(), event :: TachyonHandler.update_event()) :: :ok
  def handle_update_event(session_pid, event) do
    send(session_pid, {:update_event, event})
  end

  @spec ack_update_event(pid(), TachyonBattle.id(), DateTime.t()) :: :ok
  def ack_update_event(session_pid, battle_id, timestamp) do
    send(session_pid, {:ack_update_event, battle_id, timestamp})
  end

  @doc """
  Ask the autohost to terminate the given battle
  """
  @spec kill_battle(pid(), TachyonBattle.id()) :: :ok | {:error, term()}
  def kill_battle(session_pid, battle_id) do
    :gen_statem.call(session_pid, {:kill_battle, battle_id}, @default_call_timeout)
  catch
    :exit, {:noproc, _details} -> {:error, :no_autohost}
  end

  @spec reply_kill_battle(pid(), reference(), :ok | {:error, reason :: term()}) :: :ok
  def reply_kill_battle(session_pid, ref, resp) do
    send(session_pid, {:reply_kill_battle, ref, resp})
  end

  @spec add_player(pid(), TachyonBattle.Types.add_player_data()) :: :ok | {:error, term()}
  def add_player(session_pid, add_data) do
    :gen_statem.call(session_pid, {:add_player, add_data}, @default_call_timeout)
  catch
    :exit, {:noproc, _details} -> {:error, :no_autohost}
  end

  @spec reply_add_player(pid(), reference(), :ok | {:error, reason :: term()}) :: :ok
  def reply_add_player(session_pid, ref, resp) do
    send(session_pid, {:reply_add_player, ref, resp})
  end

  @doc """
  should only be used for testing, get the `since` for subscribeUpdates
  """
  def inspect_subscription_start(autohost_id) do
    autohost_id
    |> via_tuple()
    |> :gen_statem.call(:inspect_subscription_start, @default_call_timeout)
  end

  @impl :gen_statem
  @spec init({Bot.t(), pid()}) :: {:ok, state(), data(), term()}
  def init({autohost, conn_pid}) do
    Logger.metadata(actor_type: :autohost_session, actor_id: autohost.id)
    Process.link(conn_pid)
    Process.flag(:trap_exit, true)
    Logger.info("session started")
    SessionRegistry.set_value(autohost.id, 0, 0)

    data = %{
      autohost: autohost,
      conn_pid: conn_pid,
      monitors: MC.new(),
      max_battles: 0,
      current_battles: 0,
      pending_battles: %{},
      active_battles: %{},
      pending_replies: %{}
    }

    {:ok, :handshaking, data, [{:next_event, :internal, :subscribe_updates}]}
  end

  @impl :gen_statem
  def handle_event(:internal, :subscribe_updates, _state, data) do
    since = get_subscription_start(data)

    case TachyonHandler.subscribe_updates(data.conn_pid, since) do
      :ok -> {:keep_state, data}
      {:error, reason} -> {:stop, {:error, reason}}
    end
  end

  def handle_event({:call, _from}, _event, :handshaking, data) do
    {:keep_state, data, [{:postpone, true}]}
  end

  def handle_event(
        {:call, from},
        {:start_battle, _battle_id, _battle_pid, _start_script},
        _state,
        data
      )
      when data.conn_pid == nil,
      do: {:keep_state, data, [{:reply, from, {:error, :no_host_available}}]}

  def handle_event(
        {:call, from},
        {:start_battle, battle_id, battle_pid, start_script},
        _state,
        data
      ) do
    TachyonHandler.start_battle(data.conn_pid, battle_id, start_script)

    data =
      data
      |> Map.update!(:pending_battles, &Map.put(&1, battle_id, {from, start_script}))
      |> Map.update!(:monitors, &MC.monitor(&1, battle_pid, {:battle, battle_id}))

    {:keep_state, data}
  end

  def handle_event({:call, from}, {:send_message, _payload}, _state, data)
      when data.conn_pid == nil,
      do: {:keep_state, data, [{:reply, from, {:error, :no_autohost}}]}

  def handle_event({:call, from}, {:send_message, %{battle_id: battle_id}}, _state, data)
      when not is_map_key(data.active_battles, battle_id),
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_battle}}]}

  def handle_event({:call, from}, {:send_message, payload}, _state, data) do
    ref = make_ref()
    TachyonHandler.send_message(data.conn_pid, ref, payload)
    data = Map.update!(data, :pending_replies, &Map.put(&1, ref, from))
    {:keep_state, data}
  end

  def handle_event({:call, from}, {:kill_battle, _battle_id}, _state, data)
      when data.conn_pid == nil,
      do: {:keep_state, data, [{:reply, from, {:error, :no_autohost}}]}

  def handle_event({:call, from}, {:kill_battle, battle_id}, _state, data)
      when not is_map_key(data.active_battles, battle_id),
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_battle}}]}

  def handle_event({:call, from}, {:kill_battle, battle_id}, _state, data) do
    ref = make_ref()
    TachyonHandler.kill_battle(data.conn_pid, ref, battle_id)
    data = Map.update!(data, :pending_replies, &Map.put(&1, ref, from))
    {:keep_state, data}
  end

  def handle_event({:call, from}, {:add_player, _add_data}, _state, data)
      when data.conn_pid == nil,
      do: {:keep_state, data, [{:reply, from, {:error, :no_autohost}}]}

  def handle_event({:call, from}, {:add_player, add_data}, _state, data)
      when not is_map_key(data.active_battles, add_data.battle_id),
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_battle}}]}

  def handle_event({:call, from}, {:add_player, add_data}, _state, data) do
    ref = make_ref()
    TachyonHandler.add_player(data.conn_pid, ref, add_data)
    data = Map.update!(data, :pending_replies, &Map.put(&1, ref, from))
    {:keep_state, data}
  end

  def handle_event({:call, from}, :inspect_subscription_start, _state, data) do
    {:keep_state, data, [{:reply, from, get_subscription_start(data)}]}
  end

  def handle_event(:info, {:reply_kill_battle, ref, _resp}, _state, data)
      when not is_map_key(data.pending_replies, ref),
      do: {:keep_state, data}

  def handle_event(:info, {:reply_kill_battle, ref, resp}, _state, data) do
    {from, pending_replies} = Map.pop!(data.pending_replies, ref)
    data = %{data | pending_replies: pending_replies}
    GenServer.reply(from, resp)
    {:keep_state, data}
  end

  def handle_event(:info, {:reply_add_player, ref, _resp}, _state, data)
      when not is_map_key(data.pending_replies, ref),
      do: {:keep_state, data}

  def handle_event(:info, {:reply_add_player, ref, resp}, _state, data) do
    {from, pending_replies} = Map.pop!(data.pending_replies, ref)
    data = %{data | pending_replies: pending_replies}
    GenServer.reply(from, resp)
    {:keep_state, data}
  end

  def handle_event(:info, {:DOWN, ref, :process, _pid, _reason}, _state, data) do
    val = MC.get_val(data.monitors, ref)
    data = Map.update!(data, :monitors, &MC.demonitor_by_val(&1, val))

    data =
      case val do
        {:battle, battle_id} ->
          data
          |> Map.update!(:pending_battles, &Map.delete(&1, battle_id))
          |> Map.update!(:active_battles, &Map.delete(&1, battle_id))
      end

    {:keep_state, data}
  end

  def handle_event(:info, {:EXIT, from, reason}, _state, data) do
    Logger.info(
      "Exit sent from #{inspect(from)} because #{inspect(reason)}. Conn pid is #{inspect(data.conn_pid)}"
    )

    {:stop, reason}
  end

  def handle_event(:info, {:update_capacity, max_battles, current_battles}, state, data) do
    data = %{data | max_battles: max_battles, current_battles: current_battles}
    SessionRegistry.set_value(data.autohost.id, max_battles, current_battles)

    case state do
      :handshaking -> {:next_state, :connected, data}
      _other -> {:keep_state, data}
    end
  end

  def handle_event(:info, {:reply_start_battle, battle_id, _resp}, _state, data)
      when not is_map_key(data.pending_battles, battle_id), do: {:keep_state, data}

  def handle_event(:info, {:reply_start_battle, battle_id, resp}, _state, data) do
    {{from, start_script}, pending_battles} = Map.pop!(data.pending_battles, battle_id)

    case resp do
      {:error, reason} ->
        GenServer.reply(from, {:error, reason})
        {:keep_state, data}

      {:ok, start_response} ->
        battle_data = %{
          start_script: start_script,
          ips: start_response.ips,
          port: start_response.port,
          pending_acks: :queue.new(),
          last_acked_ts: nil
        }

        data =
          data
          |> Map.replace!(:pending_battles, pending_battles)
          |> Map.update!(:active_battles, &Map.put(&1, battle_id, battle_data))

        GenServer.reply(from, {:ok, self(), start_response})

        {:keep_state, data}
    end
  end

  def handle_event(:info, {:reply_send_message, ref, _resp}, _state, data)
      when not is_map_key(data.pending_replies, ref) do
    {:keep_state, data}
  end

  def handle_event(:info, {:reply_send_message, ref, resp}, _state, data) do
    {from, pending_replies} = Map.pop!(data.pending_replies, ref)
    data = %{data | pending_replies: pending_replies}
    GenServer.reply(from, resp)
    {:keep_state, data}
  end

  # TODO: will need to "resurrect" a battle if we ever get into this situation.
  # Because the autohost is the ultimate source of truth when it comes to running
  # battle, so if it tells teiserver that something is running, we need to
  # create a corresponding process. But for now, just drop the message
  def handle_event(:info, {:update_event, %{battle_id: battle_id}}, _state, data)
      when not is_map_key(data.active_battles, battle_id),
      do: {:keep_state, data}

  def handle_event(:info, {:update_event, event}, _state, data) do
    TachyonBattle.send_update_event(event)

    data =
      data
      |> update_in([:active_battles, event.battle_id, :pending_acks], &:queue.in(event.time, &1))

    {:keep_state, data}
  end

  def handle_event(:info, {:ack_update_event, battle_id, _timestamp}, _state, data)
      when not is_map_key(data.active_battles, battle_id),
      do: {:keep_state, data}

  def handle_event(:info, {:ack_update_event, battle_id, timestamp}, _state, data) do
    data =
      update_in(data, [:active_battles, battle_id], fn battle_data ->
        case :queue.out(battle_data.pending_acks) do
          {{:value, ^timestamp}, q2} ->
            %{battle_data | pending_acks: q2, last_acked_ts: timestamp}

          {:empty, _queue} ->
            Logger.warning("battle #{battle_id} acked a message but nothing is waiting")
            data
            # battle should *always* ack message in order, so if the acked message is
            # not the first in the queue, something is seriously wrong
        end
      end)

    {:keep_state, data}
  end

  defp via_tuple(autohost_id) do
    SessionRegistry.via_tuple(autohost_id)
  end

  # the typespec for DateTime.shift/2 requires the duration pair for
  # :microsecond to have non negative integer.
  # but it works just fine with negative number
  @dialyzer {:nowarn_function, get_subscription_start: 1}
  defp get_subscription_start(state) do
    for {_battle_id, battle_data} <- state.active_battles do
      case {battle_data.last_acked_ts, :queue.peek(battle_data.pending_acks)} do
        {x, _pending} when not is_nil(x) ->
          x

        {nil, {:value, x}} ->
          # subscriptions work with a strict bound: anything `>` than the provided
          # timestamp. Which means if we return the exact timestamp of the last event
          # this specific event won't be returned.
          DateTime.shift(x, microsecond: {-1, 6})

        _other ->
          nil
      end
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.min(fn -> DateTime.utc_now() end)
  end
end
