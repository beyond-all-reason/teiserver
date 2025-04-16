defmodule Teiserver.Party.Server do
  @moduledoc """
  transient genserver to hold a party state and mediate player interactions
  """

  alias Teiserver.Party
  alias Teiserver.Player
  alias Teiserver.Data.Types, as: T

  use GenServer, restart: :transient
  alias Teiserver.Data.Types, as: T

  @type id :: String.t()
  @type state :: %{
          # versionning of the state to avoid races between call and cast
          version: integer(),
          id: id(),
          members: [%{id: T.userid(), joined_at: DateTime.t()}],
          invited: [%{id: T.userid(), invited_at: DateTime.t()}]
        }

  @spec gen_party_id() :: id()
  def gen_party_id(), do: UUID.uuid4()

  @spec leave_party(id(), T.userid()) :: :ok | {:error, :invalid_party | :not_a_member}
  def leave_party(party_id, user_id) do
    GenServer.call(via_tuple(party_id), {:leave, user_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
  end

  @doc """
  Create an invite for the given player, ensuring they're not alreay part of the party
  """
  @spec create_invite(id(), T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :already_invited}
  def create_invite(party_id, user_id) do
    GenServer.call(via_tuple(party_id), {:create_invite, user_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
  end

  @spec accept_invite(id(), T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :not_invited}
  def accept_invite(party_id, user_id) do
    GenServer.call(via_tuple(party_id), {:accept_invite, user_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
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

  def start_link({party_id, _user_id} = args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(party_id))
  end

  @impl true
  def init({party_id, user_id}) do
    state = %{
      version: 0,
      id: party_id,
      members: add_member([], user_id),
      invited: []
    }

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

  def handle_call({:create_invite, user_id}, _from, state) do
    invited = Enum.find(state.invited, fn %{id: id} -> id == user_id end)
    member = Enum.find(state.members, fn %{id: id} -> id == user_id end)

    if invited != nil || member != nil do
      {:reply, {:error, :already_invited}, state}
    else
      invite = %{id: user_id, invited_at: DateTime.utc_now()}

      new_state =
        state
        |> Map.put(:invited, [invite | state.invited])
        |> bump()

      # don't send the updated event to the newly invited player
      for %{id: id} <- state.invited ++ state.members do
        Player.party_notify_updated(id, new_state)
      end

      # TODO: add a timeout and cancel the invite after it

      {:reply, {:ok, new_state}, new_state}
    end
  end

  def handle_call({:accept_invite, user_id}, _from, state) do
    case Enum.split_with(state.invited, fn %{id: id} -> id == user_id end) do
      {[], _} ->
        {:reply, {:error, :not_invited}, state}

      {[_], rest} ->
        state =
          state
          |> bump()
          |> Map.put(:invited, rest)
          |> Map.update!(:members, &add_member(&1, user_id))

        notify_updated(state)
        {:reply, {:ok, state}, state}
    end
  end

  defp notify_updated(state) do
    for %{id: id} <- state.invited ++ state.members do
      Player.party_notify_updated(id, state)
    end

    state
  end

  defp via_tuple(party_id) do
    Party.Registry.via_tuple(party_id)
  end

  defp bump(state), do: Map.update!(state, :version, &(&1 + 1))

  defp add_member(members, user_id), do: [%{id: user_id, joined_at: DateTime.utc_now()} | members]
end
