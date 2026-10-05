defmodule Teiserver.Cluster.DistributedGenStatem do
  @moduledoc """
  This module defines both a behaviour and a wrapper for gen_statem
  It allows wrapped gen_statem module to delegate state replication
  across multiple node and focus on their own logic.
  """

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
  This is the same as c:gen_statem.handle_event/4
  """
  @callback handle_event(
              event_type :: :gen_statem.event_type(),
              event_content :: term(),
              current_state :: term(),
              data :: term()
            ) :: :gen_statem.event_handler_result(term())

  @doc """
  the internal data used by the wrapper module
  """
  @enforce_keys [:mod, :id, :module_data]
  defstruct [
    # the wrapped gen_statem
    :mod,
    # unique ID for the wrapped module. Also used to derive a name
    # (typically a via tuple)
    :id,
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

        DynamicSupervisor.start_child(sup, {__MODULE__, {id, init_arg}})
      end

      defoverridable start: 2
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
  def init({mod, id, init_args}) do
    case mod.init(init_args) do
      {:ok, state, data} ->
        {:ok, state,
         %__MODULE__{
           mod: mod,
           id: id,
           module_data: data
         }}

      {:ok, state, data, actions} ->
        {:ok, state,
         %__MODULE__{
           mod: mod,
           id: id,
           module_data: data
         }, actions}

      :ignore ->
        :ignore

      {:stop, reason} ->
        {:stop, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl :gen_statem
  def handle_event(event_type, event_data, state, %__MODULE__{} = data) do
    case data.mod.handle_event(event_type, event_data, state, data.module_data) do
      {:next_state, new_state, new_data} ->
        wrapped_data = %{data | module_data: new_data}
        {:next_state, new_state, wrapped_data}

      {:next_state, new_state, new_data, actions} ->
        wrapped_data = %{data | module_data: new_data}
        {:next_state, new_state, wrapped_data, actions}

      {typ, new_data} when typ in [:keep_state, :repeat_state] ->
        wrapped_data = %{data | module_data: new_data}
        {:keep_state, wrapped_data}

      {typ, new_data, actions} when typ in [:keep_state, :repeat_state] ->
        wrapped_data = %{data | module_data: new_data}
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

  # not a blind `defdelegate`, put a default timeout
  def call(server_ref, request, timeout \\ :timer.seconds(5)) do
    :gen_statem.call(server_ref, request, timeout)
  end
end
