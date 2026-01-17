defmodule Teiserver.Autohost.SessionRegistry do
  @moduledoc """
  Registry used to identify autohost sessions
  """

  def start_link() do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  How to reach a given session
  """
  # @spec via_tuple(T.userid()) :: GenServer.name()
  def via_tuple(autohost_id) do
    {:via, Registry, {__MODULE__, autohost_id}}
  end

  # @spec lookup(T.userid()) :: pid() | nil
  def lookup(autohost_id) do
    case Registry.lookup(__MODULE__, autohost_id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  def child_spec(_) do
    Supervisor.child_spec(Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  def count() do
    Registry.count(__MODULE__)
  end
end
