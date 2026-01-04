defmodule Teiserver.Party.Registry do
  @moduledoc """
  Tracks tachyon parties
  """

  alias Teiserver.Party

  @spec lookup(Party.Server.id()) :: pid() | nil
  def lookup(party_id) do
    case Horde.Registry.lookup(__MODULE__, party_id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @spec count() :: non_neg_integer()
  def count() do
    case Horde.Registry.count(__MODULE__) do
      :undefined -> 0
      x -> x
    end
  end

  def start_link() do
    Horde.Registry.start_link(keys: :unique, name: __MODULE__)
  end

  def child_spec(_) do
    Supervisor.child_spec(Horde.Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  def via_tuple(party_id) do
    {:via, Horde.Registry, {__MODULE__, party_id}}
  end
end
