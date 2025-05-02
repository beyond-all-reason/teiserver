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
          pid: pid(),
          members: [%{id: T.userid(), joined_at: DateTime.t(), mon_ref: reference()}],
          invited: [
            %{
              id: T.userid(),
              invited_at: DateTime.t(),
              mon_ref: reference(),
              valid_until: DateTime.t(),
              timeout_ref: :timer.tref()
            }
          ]
        }

  @spec gen_party_id() :: id()
  def gen_party_id(), do: UUID.uuid4()

  @doc """
  What is the site config key holding the max size of a party
  """
  def max_size_key(), do: "party.max-size"

  @doc """
  What is the site config key holding how long an invite is valid for (in seconds)
  """
  def invite_valid_duration_key(), do: "party.invite-valid-duration-s"

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
          {:ok, state()} | {:error, :invalid_party | :already_invited | :party_at_capacity}
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

  @spec decline_invite(id(), T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :not_invited}
  def decline_invite(party_id, user_id) do
    GenServer.call(via_tuple(party_id), {:decline_invite, user_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
  end

  @doc """
  cancel a pending invite. Any member can do that
  """
  @spec cancel_invite(id(), T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :not_in_party | :not_invited}
  def cancel_invite(party_id, user_id) do
    GenServer.call(via_tuple(party_id), {:cancel_invite, user_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
  end

  @doc """
  Kick the specified member from the party. The user doing the kicking must
  be a member of the party (and not merely invited)
  """
  @spec kick_user(id(), user_kicking :: T.userid(), kicked_user :: T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :invalid_target | :not_a_member}
  def kick_user(party_id, actor_id, target_id) do
    GenServer.call(via_tuple(party_id), {:kick_user, actor_id, target_id})
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
      pid: self(),
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

    max_size = Teiserver.Config.get_site_config_cache(max_size_key())

    cond do
      invited != nil || member != nil ->
        {:reply, {:error, :already_invited}, state}

      Enum.count(state.invited) + Enum.count(state.members) >= max_size ->
        {:reply, {:error, :party_at_capacity}, state}

      true ->
        valid_duration = Teiserver.Config.get_site_config_cache(invite_valid_duration_key())
        valid_until = DateTime.add(DateTime.utc_now(), valid_duration, :second)
        tref = :timer.send_after(valid_duration * 1000, {:invite_timeout, user_id})

        monitor = Player.monitor_session(user_id)

        invite = %{
          id: user_id,
          invited_at: DateTime.utc_now(),
          mon_ref: monitor,
          valid_until: valid_until,
          timeout_ref: tref
        }

        new_state =
          state
          |> Map.put(:invited, [invite | state.invited])
          |> bump()

        # don't send the updated event to the newly invited player
        for %{id: id} <- state.invited ++ state.members do
          Player.party_notify_updated(id, new_state)
        end

        {:reply, {:ok, new_state}, new_state}
    end
  end

  def handle_call({:accept_invite, user_id}, _from, state) do
    case Enum.split_with(state.invited, fn %{id: id} -> id == user_id end) do
      {[], _} ->
        {:reply, {:error, :not_invited}, state}

      {[invited], rest} ->
        state =
          state
          |> bump()
          |> Map.put(:invited, rest)
          |> Map.update!(:members, &add_member(&1, user_id, invited.mon_ref))

        notify_updated(state)
        {:reply, {:ok, state}, state}
    end
  end

  def handle_call({:decline_invite, user_id}, _from, state) do
    case Enum.split_with(state.invited, fn %{id: id} -> id == user_id end) do
      {[], _} ->
        {:reply, {:error, :not_invited}, state}

      {[invited], rest} ->
        Process.demonitor(invited.mon_ref)
        :timer.cancel(invited.timeout_ref)

        state =
          state
          |> bump()
          |> Map.put(:invited, rest)

        notify_updated(state)

        {:reply, {:ok, state}, state}
    end
  end

  def handle_call({:cancel_invite, user_id}, _from, state) do
    case Enum.split_with(state.invited, fn %{id: id} -> id == user_id end) do
      {[], _} ->
        {:reply, {:error, :not_invited}, state}

      {[invite], rest} ->
        state = cancel_invite_internal(invite, rest, state)
        {:reply, {:ok, state}, state}
    end
  end

  def handle_call({:kick_user, actor_id, target_id}, _from, state) do
    member? = Enum.find(state.members, &(&1.id == actor_id)) != nil
    other_members = Enum.split_with(state.members, &(&1.id == target_id))

    case {member?, other_members} do
      {false, _} ->
        {:reply, {:error, :not_a_member}, state}

      {_, {[], _}} ->
        {:reply, {:error, :invalid_target}, state}

      {true, {[member], rest}} ->
        Process.demonitor(member.mon_ref)
        state = state |> bump() |> Map.put(:members, rest)
        Player.party_notify_removed(target_id, state)
        notify_updated(state)
        {:reply, {:ok, state}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    in_members = Enum.split_with(state.members, &(&1.mon_ref == ref))
    in_invited = Enum.split_with(state.invited, &(&1.mon_ref == ref))

    state =
      case {in_members, in_invited} do
        {{[_], rest}, _} ->
          Map.put(state, :members, rest)
          |> notify_updated()

        {_, {[_], rest}} ->
          Map.put(state, :invited, rest)
          |> notify_updated()

        _ ->
          state
      end

    {:noreply, state}
  end

  def handle_info({:invite_timeout, user_id}, state) do
    case Enum.split_with(state.invited, &(&1.id == user_id)) do
      {[invite], rest} ->
        state = cancel_invite_internal(invite, rest, state)
        {:noreply, state}

      _ ->
        {:noreply, state}
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

  defp add_member(members, user_id) do
    monitor = Player.monitor_session(user_id)
    if monitor == nil, do: raise("member not connected")
    add_member(members, user_id, monitor)
  end

  defp add_member(members, user_id, monitor) do
    [%{id: user_id, joined_at: DateTime.utc_now(), mon_ref: monitor} | members]
  end

  defp cancel_invite_internal(invite, other_invites, state) do
    Process.demonitor(invite.mon_ref)
    :timer.cancel(invite.timeout_ref)
    state = state |> bump() |> Map.put(:invited, other_invites)
    Player.party_notify_removed(invite.id, state)
    notify_updated(state)
    state
  end
end
