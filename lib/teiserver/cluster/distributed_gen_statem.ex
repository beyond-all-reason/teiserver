defmodule Teiserver.Cluster.DistributedGenStatem do
  @moduledoc """
  This module defines both a behaviour and a wrapper for gen_statem
  It allows wrapped gen_statem module to delegate state replication
  across multiple node and focus on their own logic.
  """

  alias Teiserver.Cluster

  @doc """
  When it is required to create a new gen_statem process wrapping the module,
  generally on a different node, it will be created under this supervisor.
  The returned module should be a running DynamicSupervisor.
  """
  @callback supervisor() :: term()

  @doc """
  How to reach the processes. This is expected to be a via tuple or a local
  name. This function is used at process creation to register it, and then
  to route messages to it.
  A typical value for this is {:via, SomeRegistry, {__MODULE__, id}}
  """
  @callback name(id :: term()) :: :gen_statem.server_name()

  @doc """
  function called when the first process is created. It is the same as
  :gen_statem.init/1

  A different function is used to create a process with a bootstrapped state
  seeded from running replica on other nodes.
  """
  @callback init(args :: term()) ::
              :gen_statem.init_result(state_type :: term(), data :: term())

  @doc """
  An optional callback to give the wrapped module a chance to run
  some logic when it starts from state and data coming from an existing
  process living on another node.
  This can happens when a new node is added to the cluster
  """
  @callback init_from_seed(state :: term(), data :: term()) :: :ok | {:error, reason :: term()}

  @doc """
  Optional callback to customize the routing key used with rendez vous hashing
  to determine which node is the primary, and which nodes are the replica.
  defaults to {wrapped_module, id}
  """
  @callback routing_key(id :: term()) :: term()

  @doc """
  This is the same as c:gen_statem.handle_event/4
  """
  @callback handle_event(
              event_type :: :gen_statem.event_type(),
              event_content :: term(),
              current_state :: term(),
              data :: term()
            ) :: :gen_statem.event_handler_result(term())

  @optional_callbacks [init_from_seed: 2, routing_key: 1]

  @doc """
  the internal data used by the wrapper module
  """
  @enforce_keys [:mod, :id, :version, :module_data]
  defstruct [
    # the wrapped gen_statem
    :mod,
    # unique ID for the wrapped module. Also used to derive a name
    # (typically a via tuple)
    :id,
    # versionning of the underlying module data
    :version,
    # the wrapped data
    :module_data
  ]

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Teiserver.Cluster.DistributedGenStatem

      alias Teiserver.Cluster.DistributedGenStatem

      def child_spec({id, args}) do
        %{
          id: name(id),
          start: {DistributedGenStatem, :start_link, [__MODULE__, id, args]},
          restart: :temporary
        }
      end

      defoverridable child_spec: 1

      @doc """
      helper function to create a gen_statem wrapping the module
      """
      def start(id, init_arg) do
        sup =
          if function_exported?(__MODULE__, :supervisor, 0) do
            __MODULE__.supervisor()
          else
            raise "#{inspect(__MODULE__)} doesn't implement supervisor/0"
          end

        mfa = {DynamicSupervisor, :start_child, [sup, {__MODULE__, {id, init_arg}}]}
        __MODULE__.routing_key(id) |> Cluster.primary_apply(mfa)
      end

      defoverridable start: 2

      def routing_key(id), do: {__MODULE__, id}
      defoverridable routing_key: 1
    end
  end

  @doc """
  Create a gen_statem process wrapping the given module.

  There should be no need to call this function directly. It is invoked through
  the generated child_spec/1 of the wrapped module.
  """
  def start_link(mod, id, init_args) do
    mod.name(id) |> :gen_statem.start_link(__MODULE__, {mod, id, init_args}, [])
  end

  @behaviour :gen_statem

  @impl :gen_statem
  def callback_mode, do: :handle_event_function

  @impl :gen_statem
  def init({mod, id, :create_replica}) do
    # this is fine since we are replicating on all nodes. If we ever
    # create replica on only a subset of nodes, this will need to change to
    # instead get the primary and all the replica + 1 (ordered by the hash)
    nodes = Cluster.get_nodes() |> Enum.reject(&(&1 == Node.self()))

    case nodes do
      [] ->
        {:error, {:seed_error, :no_node}}

      nodes ->
        args = [mod.name(id), :seed_process, :timer.seconds(5)]
        init_on_nodes(nodes, mod, args)
    end
  end

  def init({mod, _id, {:init_replica, state, data}}) do
    result =
      if function_exported?(mod, :init_from_seed, 2),
        do: mod.init_from_seed(state, data.module_data),
        else: :ok

    case result do
      :ok -> {:ok, state, data}
      {:error, reason} -> {:error, {:seed_error, reason}}
    end
  end

  def init({mod, id, init_args}) do
    case mod.init(init_args) do
      {:ok, state, data} ->
        data = %__MODULE__{
          mod: mod,
          id: id,
          version: 0,
          module_data: data
        }

        create_replicas(state, data)

        {:ok, state, data}

      {:ok, state, data, actions} ->
        data = %__MODULE__{
          mod: mod,
          id: id,
          version: 0,
          module_data: data
        }

        create_replicas(state, data)

        {:ok, state, data, actions}

      :ignore ->
        :ignore

      {:stop, reason} ->
        {:stop, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp init_on_nodes(nodes, mod, args) do
    # TODO: make this multicall into an async operation, so that it cannot
    # deadlock when this process receives a :gen_statem.call while waiting
    # for a response to its :seed_process call itself
    {state, %__MODULE__{} = data} =
      :erpc.multicall(nodes, :gen_statem, :call, args, :timer.seconds(5))
      |> Enum.reduce(nil, fn {:ok, {state, data}}, final_result ->
        case final_result do
          nil ->
            {state, data}

          {_state, final_data} ->
            if final_data.version >= data.version do
              final_result
            else
              {state, data}
            end
        end
      end)

    case mod.init_from_seed(state, data.module_data) do
      :ok -> {:ok, state, data}
      {:error, reason} -> {:error, {:seed_error, reason}}
    end
  end

  @impl :gen_statem
  def handle_event({:call, from}, :seed_process, state, data) do
    {:keep_state_and_data, [{:reply, from, {state, data}}]}
  end

  def handle_event(event_type, event_data, state, %__MODULE__{} = data) do
    case data.mod.handle_event(event_type, event_data, state, data.module_data) do
      {:next_state, new_state, new_data} ->
        wrapped_data = %{data | version: data.version + 1, module_data: new_data}
        {:next_state, new_state, wrapped_data}

      {:next_state, new_state, new_data, actions} ->
        wrapped_data = %{data | version: data.version + 1, module_data: new_data}
        {:next_state, new_state, wrapped_data, actions}

      {typ, new_data} when typ in [:keep_state, :repeat_state] ->
        wrapped_data = %{data | version: data.version + 1, module_data: new_data}
        {:keep_state, wrapped_data}

      {typ, new_data, actions} when typ in [:keep_state, :repeat_state] ->
        wrapped_data = %{data | version: data.version + 1, module_data: new_data}
        {:keep_state, wrapped_data, actions}

      # the other possible actions are :repeat_state_and data, which doesn't
      # modify anything we track (state and data).
      # or a bunch of actions that result in stopping, so no need to do
      # anything else
      other ->
        other
    end
  end

  @impl :gen_statem
  def terminate(reason, state, %__MODULE__{} = data) do
    if function_exported?(data.mod, :terminate, 3) do
      data.mod.terminate(reason, state, data.module_data)
    else
      :ok
    end
  end

  def call({mod, id}, request, timeout \\ :timer.seconds(5)) do
    mfa = {:gen_statem, :call, [mod.name(id), request, timeout]}
    mod.routing_key(id) |> Cluster.primary_apply(mfa)
  catch
    :exit, {:exception, {:noproc, reason}} ->
      case Cluster.get_nodes() do
        [_node] ->
          exit({:noproc, reason})

        _more_nodes ->
          # TODO: handle the case where this fails
          case mod.start(id, :create_replica) do
            {:ok, pid} ->
              :gen_statem.call(pid, request, timeout)

            {:error, {:already_started, pid}} ->
              :gen_statem.call(pid, request, timeout)

            {:error, {:seed_error, reason}} ->
              kill_all(mod, id)
              exit({:noproc, {:seed_error, reason}})

            err ->
              err
          end
      end
  end

  defp create_replicas(state, %__MODULE__{} = data) do
    {_primary, replicas} = data.mod.routing_key(data.id) |> Cluster.split_nodes()

    case replicas do
      [] ->
        :ok

      replicas ->
        sup = data.mod.supervisor()
        args = [sup, {data.mod, {data.id, {:init_replica, state, data}}}]
        :erpc.multicall(replicas, DynamicSupervisor, :start_child, args)
        :ok
    end
  end

  defp kill_all(mod, id) do
    # send the request to kill on *all* nodes. We are likely to replicate on all
    # nodes anyway. Otherwise, we can restrict to primary + replicas + 1
    # though this call should rarely happen, so it's likely to be irrelevant
    Cluster.get_nodes()
    |> :erpc.multicall(__MODULE__, :kill_process, [mod, id], :timer.seconds(5))
  end

  def kill_process(mod, id) do
    case whereis(mod.name(id)) do
      pid when is_pid(pid) ->
        Process.exit(pid, :kill)

      nil ->
        nil
    end
  end

  defp whereis(name) when is_atom(name), do: Process.whereis(name)

  defp whereis({:via, reg, {reg_name, key}}) do
    case reg.lookup(reg_name, key) do
      [{pid, _val}] -> pid
      _other -> nil
    end
  end

  defp whereis(name), do: raise("unsupported name: #{inspect(name)}")
end
