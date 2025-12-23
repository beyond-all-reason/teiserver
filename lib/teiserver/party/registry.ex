defmodule Teiserver.Party.Registry do
  @moduledoc """
  Tracks tachyon parties
  """

  alias Teiserver.Party

  @spec lookup(Party.Server.id()) :: pid() | nil
  def lookup(party_id) do
    case Registry.lookup(__MODULE__, party_id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @spec count() :: non_neg_integer()
  def count(), do: Registry.count(__MODULE__)

  def start_link() do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  def child_spec(_) do
    Supervisor.child_spec(Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  def via_tuple(party_id) do
    {:via, Registry, {__MODULE__, party_id}}
  end
end
