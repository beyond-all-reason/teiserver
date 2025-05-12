defmodule Teiserver.Party.Server do
  @moduledoc """
  transient genserver to hold a party state and mediate player interactions
  """

  alias Teiserver.Party
  alias Teiserver.Player
  alias Teiserver.Matchmaking
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Helpers.MonitorCollection, as: MC

  use GenServer, restart: :transient
  alias Teiserver.Data.Types, as: T

  @type id :: String.t()
  @type state :: %{
          # versionning of the state to avoid races between call and cast
          version: integer(),
          id: id(),
          pid: pid(),
          monitors: MC.t(),
          members: [%{id: T.userid(), joined_at: DateTime.t()}],
          invited: [
            %{
              id: T.userid(),
              invited_at: DateTime.t(),
              valid_until: DateTime.t(),
              timeout_ref: :timer.tref()
            }
          ],
          matchmaking: nil | %{queues: [Matchmaking.queue_id()]}
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

  @doc """
  Make all the members of the party join the specified matchmaking queues.
  The party server will only notify the members that they should join the
  specified queues.

  Once the party is in matchmaking, it is "locked", all invites are cancelled
  and no new invites can be sent.
  We may revisit this decision later, but for now it drastically simplify the
  interactions between parties and matchmaking by removing any potential of a
  party member already being in matchmaking outside the party.
  """
  @spec join_queues(id(), [Matchmaking.queue_id()]) :: :ok | {:error, reason :: term()}
  def join_queues(party_id, queues) do
    GenServer.call(via_tuple(party_id), {:join_matchmaking_queues, queues})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
  end

  @doc """
  Let the party know that it is no longer in matchmaking. The responsability
  to let the player know falls upon the matchmaking system, this is only
  to set the party state.
  """
  @spec matchmaking_notify_cancel(id()) :: :ok
  def matchmaking_notify_cancel(party_id) do
    GenServer.cast(via_tuple(party_id), :lost_matchmaking_queue)
  end

  def start_link({party_id, _user_id} = args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(party_id))
  end

  @impl true
  def init({party_id, user_id}) do
    state =
      %{
        version: 0,
        id: party_id,
        pid: self(),
        monitors: MC.new(),
        members: [],
        invited: [],
        matchmaking: nil
      }
      |> add_member(user_id)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @spec handle_call(term(), GenServer.from(), state()) :: term()
  def handle_call({:leave, user_id}, _from, state) do
    case Enum.split_with(state.members, fn %{id: mid} -> mid == user_id end) do
      {[], _} ->
        {:reply, {:error, :not_a_member}, state}

      {[_], []} ->
        {:stop, :normal, :ok, %{state | members: []} |> bump()}

      {[_], new_members} ->
        new_state = %{state | members: new_members} |> bump()

        for %{id: id} <- state.invited ++ state.members do
          Player.party_notify_updated(id, new_state)
        end

        {:reply, :ok, new_state}
    end
  end

  def handle_call({:create_invite, _user_id}, _from, state)
      when state.matchmaking != nil,
      do: {:reply, {:error, :party_in_matchmaking}, state}

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

        invite = %{
          id: user_id,
          invited_at: DateTime.utc_now(),
          valid_until: valid_until,
          timeout_ref: tref
        }

        new_state =
          state
          |> Map.put(:invited, [invite | state.invited])
          |> Map.update!(:monitors, fn m ->
            Player.add_session_monitor(m, user_id, {:invite, user_id})
          end)
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

      {[_invited], rest} ->
        state =
          state
          |> bump()
          |> Map.put(:invited, rest)
          |> add_member(user_id)

        notify_updated(state)
        {:reply, {:ok, state}, state}
    end
  end

  def handle_call({:decline_invite, user_id}, _from, state) do
    case Enum.split_with(state.invited, fn %{id: id} -> id == user_id end) do
      {[], _} ->
        {:reply, {:error, :not_invited}, state}

      {[invited], rest} ->
        :timer.cancel(invited.timeout_ref)

        state =
          state
          |> Map.update!(:monitors, fn mc ->
            MC.demonitor_by_val(mc, {:invite, user_id})
          end)
          |> bump()
          |> Map.put(:invited, rest)

        notify_updated(state)

        {:reply, {:ok, state}, state}
    end
  end

  def handle_call({:cancel_invite, user_id}, _from, state) do
    case Enum.find(state.invited, fn %{id: id} -> id == user_id end) do
      nil ->
        {:reply, {:error, :not_invited}, state}

      invite ->
        state = cancel_invite_internal(invite, state)
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

      {true, {[_member], rest}} ->
        state =
          state
          |> bump()
          |> Map.update!(:monitors, &MC.demonitor_by_val(&1, {:member, target_id}))
          |> Map.put(:members, rest)

        Player.party_notify_removed(target_id, state)
        notify_updated(state)
        {:reply, {:ok, state}, state}
    end
  end

  def handle_call({:join_matchmaking_queues, _queues}, _from, state)
      when not is_nil(state.matchmaking),
      do: {:reply, {:error, :already_queued}, state}

  def handle_call({:join_matchmaking_queues, queues}, _from, state) do
    members_id = Enum.map(state.members, fn m -> %{id: m.id} end)

    result =
      Enum.reduce_while(queues, state.monitors, fn q_id, monitors ->
        case Matchmaking.party_join_queue(q_id, state.id, members_id) do
          {:ok, queue_pid} ->
            {:cont, MC.monitor(monitors, queue_pid, {:queue, q_id})}

          {:error, reason} ->
            {:halt, {:error, reason, monitors}}
        end
      end)

    case result do
      {:error, reason, monitors} ->
        # for simplicity, just demonitor everything, even if the queue may not
        # have been joined yet
        state =
          Map.replace!(
            state,
            :monitors,
            Enum.reduce(queues, monitors, &MC.demonitor_by_val(&2, {:queue, &1}))
          )

        {:reply, {:error, reason}, state}

      monitors ->
        state =
          state
          |> bump()
          |> Map.replace!(:monitors, monitors)
          |> Map.replace!(:matchmaking, %{queues: queues})

        # when entering matchmaking, "lock" the party, all invites are cancelled
        state = Enum.reduce(state.invited, state, &cancel_invite_internal(&1, &2))

        for member <- state.members do
          Player.party_notify_join_queues(member.id, queues, state)
        end

        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_cast(:lost_matchmaking_queue, state)
      when state.matchmaking == nil,
      do: {:noreply, state}

  def handle_cast(:lost_matchmaking_queue, state) do
    monitors =
      Enum.reduce(state.matchmaking.queues, state.monitors, fn queue_id, mc ->
        MC.demonitor_by_val(mc, queue_id)
      end)

    {:noreply, %{state | monitors: monitors, matchmaking: nil}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    val = MC.get_val(state.monitors, ref)
    state = Map.update!(state, :monitors, &MC.demonitor_by_val(&1, val))

    state =
      case val do
        nil ->
          state

        {:invite, user_id} ->
          Map.update!(state, :invited, fn invites ->
            Enum.filter(invites, fn i -> i.id != user_id end)
          end)
          |> notify_updated()

        {:member, user_id} ->
          Map.update!(state, :members, fn members ->
            Enum.filter(members, fn m -> m.id != user_id end)
          end)
          |> notify_updated()

        {:queue, _qid} ->
          %{state | matchmaking: nil}
      end

    {:noreply, state}
  end

  def handle_info({:invite_timeout, user_id}, state) do
    case Enum.find(state.invited, &(&1.id == user_id)) do
      nil ->
        {:noreply, state}

      invite ->
        state = cancel_invite_internal(invite, state)
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

  defp add_member(state, user_id) do
    state =
      state
      |> Map.update!(:members, fn members ->
        [%{id: user_id, joined_at: DateTime.utc_now()} | members]
      end)

    case MC.get_ref(state.monitors, {:invite, user_id}) do
      nil ->
        Map.update!(state, :monitors, fn mc ->
          Player.add_session_monitor(mc, user_id, {:member, user_id})
        end)

      _ref ->
        Map.update!(state, :monitors, fn mc ->
          MC.replace_val!(mc, {:invite, user_id}, {:member, user_id})
        end)
    end
  end

  defp cancel_invite_internal(invite, state) do
    :timer.cancel(invite.timeout_ref)

    state =
      state
      |> bump()
      |> Map.update!(:invited, fn invites -> Enum.filter(invites, &(&1 != invite)) end)
      |> Map.update!(:monitors, &MC.demonitor_by_val(&1, {:invite, invite.id}))

    Player.party_notify_removed(invite.id, state)
    notify_updated(state)
    state
  end
end
