defmodule Teiserver.Autohost.Session do
  @moduledoc """
  Similar to player's session, this is a process tied to a autohost connection
  in such a way that it survives if the connection goes away, and can be
  cleanly shutdown when required.
  """

  @behaviour :gen_statem

  alias Teiserver.Bot.Bot
  alias Teiserver.Autohost
  alias Teiserver.Autohost.{TachyonHandler, SessionRegistry}
  alias Teiserver.TachyonBattle

  require Logger

  @default_call_timeout 5000

  @typep battle_data :: %{
           start_script: Autohost.start_script(),
           ips: [String.t()],
           port: non_neg_integer()
         }

  @typep data :: %{
           autohost: Bot.t(),
           conn_pid: pid(),
           max_battles: non_neg_integer(),
           current_battles: non_neg_integer(),
           pending_battles: %{TachyonBattle.id() => {GenServer.from(), Autohost.start_script()}},
           active_battles: %{TachyonBattle.id() => battle_data()},
           pending_replies: %{reference() => GenServer.from()}
         }

  # irrelevant for now
  @typep state :: :handshaking

  def child_spec({autohost, _conn_pid} = args) do
    %{
      id: via_tuple(autohost.id),
      start: {__MODULE__, :start_link, [args]},
      restart: :temporary
    }
  end

  def start_link({autohost, _conn_pid} = arg) do
    :gen_statem.start_link(via_tuple(autohost.id), __MODULE__, arg, [])
  end

  @impl :gen_statem
  def callback_mode(), do: :handle_event_function

  @type start_response :: %{ips: [String.t()], port: integer()}
  # credo:disable-for-next-line Credo.Check.Design.TagTODO
  # TODO: there should be some kind of retry here
  @spec start_battle(Bot.id(), TachyonBattle.id(), Autohost.start_script()) ::
          {:ok, start_response()} | {:error, term()}
  def start_battle(autohost_id, battle_id, start_script) do
    :gen_statem.call(
      via_tuple(autohost_id),
      {:start_battle, battle_id, start_script},
      @default_call_timeout
    )
  catch
    :exit, {:noproc, _} -> {:error, :no_host_available}
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
    :gen_statem.call(via_tuple(autohost_id), {:send_message, payload}, @default_call_timeout)
  catch
    :exit, {:noproc, _} -> {:error, :no_autohost}
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

  @doc """
  Ask the autohost to terminate the given battle
  """
  @spec kill_battle(pid(), TachyonBattle.id()) :: :ok | {:error, term()}
  def kill_battle(session_pid, battle_id) do
    :gen_statem.call(session_pid, {:kill_battle, battle_id}, @default_call_timeout)
  catch
    :exit, {:noproc, _} -> {:error, :no_autohost}
  end

  @spec reply_kill_battle(pid(), reference(), :ok | {:error, reason :: term()}) :: :ok
  def reply_kill_battle(session_pid, ref, resp) do
    send(session_pid, {:reply_kill_battle, ref, resp})
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
    case TachyonHandler.subscribe_updates(data.conn_pid, DateTime.utc_now()) do
      :ok -> {:keep_state, data}
      {:error, reason} -> {:stop, {:error, reason}}
    end
  end

  def handle_event({:call, from}, {:start_battle, _, _}, _state, data) when data.conn_pid == nil,
    do: {:keep_state, data, [{:reply, from, {:error, :no_host_available}}]}

  def handle_event({:call, from}, {:start_battle, battle_id, start_script}, _state, data) do
    Teiserver.Autohost.TachyonHandler.start_battle(data.conn_pid, battle_id, start_script)
    data = Map.update!(data, :pending_battles, &Map.put(&1, battle_id, {from, start_script}))
    {:keep_state, data}
  end

  def handle_event({:call, from}, {:send_message, _}, _state, data) when data.conn_pid == nil,
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

  def handle_event(:info, {:EXIT, from, reason}, _state, data) do
    Logger.info(
      "Exit sent from #{inspect(from)} because #{inspect(reason)}. Conn pid is #{inspect(data.conn_pid)}"
    )

    {:stop, reason}
  end

  def handle_event(:info, {:update_capacity, max_battles, current_battles}, _state, data) do
    data = %{data | max_battles: max_battles, current_battles: current_battles}
    SessionRegistry.set_value(data.autohost.id, max_battles, current_battles)
    {:keep_state, data}
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
          port: start_response.port
        }

        data =
          data
          |> Map.replace!(:pending_battles, pending_battles)
          |> Map.update!(:active_battles, &Map.put(&1, battle_id, battle_data))

        GenServer.reply(from, {:ok, start_response})

        {:keep_state, data}
    end
  end

  def handle_event(:info, {:reply_send_message, ref, _}, _state, data)
      when not is_map_key(data.pending_replies, ref) do
    {:keep_state, data}
  end

  def handle_event(:info, {:reply_send_message, ref, resp}, _state, data) do
    {from, pending_replies} = Map.pop!(data.pending_replies, ref)
    data = %{data | pending_replies: pending_replies}
    GenServer.reply(from, resp)
    {:keep_state, data}
  end

  defp via_tuple(autohost_id) do
    SessionRegistry.via_tuple(autohost_id)
  end
end
