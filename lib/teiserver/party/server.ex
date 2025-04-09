defmodule Teiserver.Party.Server do
  @moduledoc """
  transient genserver to hold a party state and mediate player interactions
  """

  alias Teiserver.Party

  use GenServer

  @opaque id :: String.t()

  @spec gen_party_id() :: id()
  def gen_party_id(), do: UUID.uuid4()

  def start_link(party_id) do
    GenServer.start_link(__MODULE__, party_id, name: via_tuple(party_id))
  end

  @impl true
  def init(party_id) do
    state = %{id: party_id}
    {:ok, state}
  end

  def via_tuple(party_id) do
    Party.Registry.via_tuple(party_id)
  end
end
