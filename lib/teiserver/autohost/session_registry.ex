defmodule Teiserver.Autohost.SessionRegistry do
  @moduledoc """
  Registry used to identify autohost sessions
  """

  alias Teiserver.Autohost.Types, as: AT
  alias Teiserver.Bot.Bot

  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  How to reach a given session
  """
  @spec via_tuple(Bot.id()) :: GenServer.name()
  def via_tuple(autohost_id) do
    {:via, Registry, {__MODULE__, autohost_id}}
  end

  @spec register(AT.Overview.t()) :: {:ok, pid()} | {:error, {:already_registered, pid()}}
  def register(%AT.Overview{id: autohost_id} = val) do
    # this is needed mostly for tests
    Registry.register(__MODULE__, autohost_id, val)
  end

  @spec lookup(Bot.id()) :: {pid(), AT.Overview.t()} | nil
  def lookup(autohost_id) do
    case Registry.lookup(__MODULE__, autohost_id) do
      [x] -> x
      _other -> nil
    end
  end

  @spec set_value(AT.Overview.t()) :: AT.Overview.t()
  def set_value(%AT.Overview{id: autohost_id} = overview) do
    result = Registry.update_value(__MODULE__, autohost_id, fn _old -> overview end)

    if result == :error do
      Registry.register(__MODULE__, autohost_id, overview)
    end

    overview
  end

  @spec get_value(Bot.id()) :: AT.Overview.t() | nil
  def get_value(autohost_id) do
    case Registry.lookup(__MODULE__, autohost_id) do
      [{_pid, val}] -> val
      _other -> nil
    end
  end

  def child_spec(_opts) do
    Supervisor.child_spec(Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  def count do
    Registry.count(__MODULE__)
  end

  @doc """
  Returns all the currently registered autohosts sessions
  """
  @spec list() :: [AT.Overview.t()]
  def list do
    Registry.select(__MODULE__, [{{:_, :_, :"$1"}, [], [:"$1"]}])
  end
end
