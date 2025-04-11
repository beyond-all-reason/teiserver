defmodule Teiserver.Party.Server do
  @moduledoc """
  transient genserver to hold a party state and mediate player interactions
  """

  alias Teiserver.Party
  alias Teiserver.Data.Types, as: T

  use GenServer, restart: :transient
  alias Teiserver.Data.Types, as: T

  @type id :: String.t()
  @type state :: %{
          # versionning of the state to avoid races between call and cast
          version: integer(),
          id: id(),
          members: [%{id: T.userid(), joined_at: DateTime.t()}]
        }

  @spec gen_party_id() :: id()
  def gen_party_id(), do: UUID.uuid4()

  @spec leave_party(id(), T.userid()) :: :ok | {:error, :invalid_party | :not_a_member}
  def leave_party(party_id, user_id) do
    GenServer.call(via_tuple(party_id), {:leave, user_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
  end

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

  @spec handle_call(term(), GenServer.from(), state()) :: term()
  def handle_call({:leave, user_id}, _from, state) do
    case Enum.split_with(state.members, fn %{id: mid} -> mid == user_id end) do
      {[], _} -> {:reply, {:error, :not_a_member}, state}
      {[_], []} -> {:stop, :normal, :ok, %{state | members: []} |> bump()}
      {[_], new_members} -> {:reply, :ok, %{state | members: new_members} |> bump()}
    end
  end

  defp via_tuple(party_id) do
    Party.Registry.via_tuple(party_id)
  end

  defp bump(state), do: Map.update!(state, :version, &(&1 + 1))
end
