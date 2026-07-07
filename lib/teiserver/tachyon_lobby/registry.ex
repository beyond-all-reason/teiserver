defmodule Teiserver.TachyonLobby.Registry do
  @moduledoc false
  alias Teiserver.TachyonLobby.Types, as: LT

  def child_spec(_arg) do
    Supervisor.child_spec(Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  How to reach a given lobby from its ID
  """
  @spec via_tuple(LT.Types.id()) :: GenServer.name()
  def via_tuple(lobby_id) do
    {:via, Registry, {__MODULE__, lobby_id}}
  end

  @spec lookup(LT.Types.id()) :: pid() | nil
  def lookup(lobby_id) do
    case Registry.lookup(__MODULE__, lobby_id) do
      [{pid, _value}] -> pid
      _other -> nil
    end
  end

  @spec count() :: non_neg_integer()
  def count do
    Registry.count(__MODULE__)
  rescue
    # when the registry isn't up (yet), can happen with telemetry polling
    _e in ArgumentError -> 0
  end

  @spec put_overview(LT.Types.id(), LT.ListOverview.t()) :: :ok | :error
  def put_overview(lobby_id, %LT.ListOverview{} = overview) do
    case Registry.update_value(__MODULE__, lobby_id, fn _old -> overview end) do
      {_new_val, _old_val} -> :ok
      :error -> :error
    end
  end

  def list_lobbies do
    spec = [{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}]
    Registry.select(__MODULE__, spec) |> Enum.into(%{})
  end

  @doc """
  for use by the ListMonitor to be able to monitor all lobbies after a restart
  """
  @spec list_pids() :: [{LT.Types.id(), pid()}]
  def list_pids do
    spec = [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}]
    Registry.select(__MODULE__, spec)
  end

  @doc """
  useful for tests, there shouldn't be a need for that outside testing
  """
  def register(lobby_id) do
    Registry.register(__MODULE__, lobby_id, nil)
  end
end
