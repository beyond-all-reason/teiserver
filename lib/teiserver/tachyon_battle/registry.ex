defmodule Teiserver.TachyonBattle.Registry do
  @moduledoc """
  Registry to track ongoing battles, linked with a autohost
  """
  alias Teiserver.TachyonBattle.Types, as: T

  def child_spec(_) do
    Supervisor.child_spec(Horde.Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  def start_link() do
    Horde.Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @spec via_tuple(T.id()) :: GenServer.name()
  def via_tuple(battle_id) do
    {:via, Horde.Registry, {__MODULE__, battle_id}}
  end

  @spec lookup(T.id()) :: pid() | nil
  def lookup(battle_id) do
    case Horde.Registry.lookup(__MODULE__, battle_id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end
end
