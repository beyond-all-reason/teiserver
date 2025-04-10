defmodule Teiserver.Party.Server do
  @moduledoc """
  transient genserver to hold a party state and mediate player interactions
  """

  alias Teiserver.Party
  alias Teiserver.Data.Types, as: T

  use GenServer

  @type id :: String.t()
  @type state :: %{
          # versionning of the state to avoid races between call and cast
          version: integer(),
          id: id(),
          members: [%{id: T.userid(), joined_at: DateTime.t()}]
        }

  @spec gen_party_id() :: id()
  def gen_party_id(), do: UUID.uuid4()

  def start_link({party_id, _user_id} = args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(party_id))
  end

  @doc """
  Get the party state
  """
  @spec get_state(id()) :: state() | nil
  def get_state(party_id) do
    GenServer.call(via_tuple(party_id), :get_state)
  catch
    :exit, {:noproc, _} -> nil
  end

  @impl true
  def init({party_id, user_id}) do
    state = %{version: 0, id: party_id, members: [%{id: user_id, joined_at: DateTime.utc_now()}]}
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def via_tuple(party_id) do
    Party.Registry.via_tuple(party_id)
  end
end
