defmodule Teiserver.Player.SessionRegistry do
  @moduledoc """
  Registry used to track player presence
  """

  alias Teiserver.Data.Types, as: T

  def start_link() do
    Horde.Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  How to reach a given session
  """
  @spec via_tuple(T.userid()) :: GenServer.name()
  def via_tuple(user_id) do
    {:via, Horde.Registry, {__MODULE__, user_id}}
  end

  @spec lookup(T.userid()) :: pid() | nil
  def lookup(user_id) do
    case Horde.Registry.lookup(__MODULE__, user_id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @doc """
  Used only for test (for now), not sure if there's a case outside tests
  """
  def register(key, value) do
    Horde.Registry.register(Teiserver.Player.SessionRegistry, key, value)
  end

  def unregister(user_id) do
    Horde.Registry.unregister(__MODULE__, via_tuple(user_id))
  end

  def child_spec(_) do
    Supervisor.child_spec(Horde.Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  def count() do
    Horde.Registry.count(__MODULE__)
  end
end
