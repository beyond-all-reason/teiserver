defmodule Teiserver.Party.Server do
  @moduledoc """
  transient state machine to hold a party state and mediate player interactions
  """

  @behaviour :gen_statem

  require Logger

  alias Teiserver.Party
  alias Teiserver.Player
  alias Teiserver.Matchmaking
  alias Teiserver.Messaging
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Helpers.MonitorCollection, as: MC

  alias Teiserver.Data.Types, as: T

  @type id :: String.t()
  @type state :: %{
          # versionning of the state to avoid races between call and cast
          version: integer(),
          id: id(),
          pid: pid(),
          monitors: MC.t(),
          members: %{T.userid() => %{id: T.userid(), joined_at: DateTime.t()}},
          ids_to_rejoin: MapSet.t(T.userid()),
          invited: %{
            T.userid() => %{
              id: T.userid(),
              invited_at: DateTime.t(),
              valid_until: DateTime.t(),
              timeout_ref: :timer.tref()
            }
          },
          matchmaking: nil | %{queues: [{Matchmaking.queue_id(), version :: String.t()}]}
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
    :gen_statem.call(via_tuple(party_id), {:leave, user_id}, 5000)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
  end

  @doc """
  To be called when the system is starting up and recovering from a restart.
  The player has to already be in the party (member or invited).
  """
  @spec rejoin(id(), T.userid(), pid() | nil) :: :ok | {:error, :invalid_party | :not_a_member}
  def rejoin(party_id, user_id, pid \\ self()) do
    :gen_statem.call(via_tuple(party_id), {:rejoin, user_id, pid}, 5000)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
  end

  @doc """
  Create an invite for the given player, ensuring they're not alreay part of the party
  """
  @spec create_invite(id(), T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :already_invited | :party_at_capacity}
  def create_invite(party_id, user_id, pid \\ self()) do
    :gen_statem.call(via_tuple(party_id), {:create_invite, user_id, pid}, 5000)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
  end

  @spec accept_invite(id(), T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :not_invited}
  def accept_invite(party_id, user_id) do
    :gen_statem.call(via_tuple(party_id), {:accept_invite, user_id, self()}, 5000)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
  end

  @spec decline_invite(id(), T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :not_invited}
  def decline_invite(party_id, user_id) do
    :gen_statem.call(via_tuple(party_id), {:decline_invite, user_id}, 5000)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
  end

  @doc """
  cancel a pending invite. Any member can do that
  """
  @spec cancel_invite(id(), T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :not_in_party | :not_invited}
  def cancel_invite(party_id, user_id) do
    :gen_statem.call(via_tuple(party_id), {:cancel_invite, user_id}, 5000)
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
    :gen_statem.call(via_tuple(party_id), {:kick_user, actor_id, target_id}, 5000)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_party}
  end

  @doc """
  Get the party state
  """
  @spec get_state(id()) :: state() | nil
  def get_state(party_id) do
    :gen_statem.call(via_tuple(party_id), :get_state, 5000)
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
  @spec join_queues(id(), [{Matchmaking.queue_id(), version :: String.t()}]) ::
          :ok | {:error, reason :: term()}
  def join_queues(party_id, queues) do
    :gen_statem.call(via_tuple(party_id), {:join_matchmaking_queues, queues}, 5000)
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
    :gen_statem.cast(via_tuple(party_id), :lost_matchmaking_queue)
  end

  @spec send_message(id(), T.userid(), String.t()) ::
          :ok | {:error, :invalid_request, reason :: term()}
  def send_message(party_id, from_id, msg_content) do
    :gen_statem.call(via_tuple(party_id), {:send_message, from_id, msg_content}, 5000)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_request, "invalid party"}
  end

  def child_spec({party_id, _} = args) do
    %{
      id: via_tuple(party_id),
      start: {__MODULE__, :start_link, [args]},
      restart: :temporary
    }
  end

  def start_link({party_id, _} = args) do
    :gen_statem.start_link(via_tuple(party_id), __MODULE__, args, [])
  end

  ################################################################################
  #                                                                              #
  #                                  INTERNALS                                   #
  #                                                                              #
  ################################################################################

  @impl :gen_statem
  def callback_mode(), do: :handle_event_function

  @impl :gen_statem
  def init({party_id, {:user, user_id, creator_pid}}) do
    Process.flag(:trap_exit, true)
    Logger.metadata(actor_type: :party, actor_id: party_id)

    data =
      %{
        version: 0,
        id: party_id,
        pid: self(),
        monitors: MC.new(),
        members: %{},
        invited: %{},
        ids_to_rejoin: MapSet.new(),
        matchmaking: nil
      }
      |> add_member(user_id, creator_pid)

    {:ok, :running, data}
  end

  def init({party_id, {:snapshot, serialized_state}}) do
    Process.flag(:trap_exit, true)
    Logger.metadata(actor_type: :party, actor_id: party_id)
    Logger.debug("Restoring party from snapshot")

    snapshot = :erlang.binary_to_term(serialized_state)
    now = DateTime.utc_now()

    expired_invite_ids =
      Enum.filter(snapshot.invited, fn {_, i} -> not DateTime.before?(now, i.valid_until) end)
      |> Enum.map(fn {id, _} -> id end)
      |> MapSet.new()

    invited =
      for {id, i} <- snapshot.invited, not MapSet.member?(expired_invite_ids, id), into: %{} do
        duration = max(1, DateTime.diff(i.valid_until, now))
        tref = :timer.send_after(duration, {:invite_timeout, i.id})
        {id, Map.put(i, :timeout_ref, tref)}
      end

    data = %{
      version: snapshot.version,
      id: party_id,
      pid: self(),
      monitors: MC.new(),
      members: snapshot.members,
      ids_to_rejoin: MapSet.difference(snapshot.ids_to_rejoin, expired_invite_ids),
      invited: invited,
      # no restoration of matchmaking yet
      matchmaking: nil
    }

    # TODO: set a state timeout to tear down everything if stays in :starting_up
    # for too long
    {:ok, :starting_up, data}
  end

  @impl :gen_statem
  def handle_event({:call, from}, :get_state, _state, data) do
    {:keep_state, data, [{:reply, from, data}]}
  end

  def handle_event({:call, from}, {:leave, user_id}, :running, data) do
    case Map.pop(data.members, user_id) do
      {nil, _} ->
        {:keep_state, data, [{:reply, from, {:error, :not_a_member}}]}

      {_, rest} when map_size(rest) == 0 ->
        {:stop_and_reply, :normal, [{:reply, from, :ok}], %{data | members: %{}} |> bump()}

      {_, new_members} ->
        new_data =
          %{data | members: new_members}
          |> bump()
          |> Map.update!(:monitors, &MC.demonitor_by_val(&1, user_id))

        for id <- Stream.concat(Map.keys(data.invited), Map.keys(data.members)) do
          Player.party_notify_updated(id, new_data)
        end

        {:keep_state, new_data, {:reply, from, :ok}}
    end
  end

  def handle_event({:call, from}, {:create_invite, _user_id, _user_pid}, :running, data)
      when data.matchmaking != nil,
      do: {:keep_state, data, [{:reply, from, {:error, :party_in_matchmaking}}]}

  def handle_event({:call, from}, {:create_invite, user_id, user_pid}, :running, data) do
    invited = Map.get(data.invited, user_id)
    member = Map.get(data.members, user_id)

    max_size = Teiserver.Config.get_site_config_cache(max_size_key())

    cond do
      invited != nil || member != nil ->
        {:keep_state, data, [{:reply, from, {:error, :already_invited}}]}

      Enum.count(data.invited) + Enum.count(data.members) >= max_size ->
        {:keep_state, data, [{:reply, from, {:error, :party_at_capacity}}]}

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

        new_data =
          data
          |> Map.update!(:invited, &Map.put(&1, user_id, invite))
          |> Map.update!(:monitors, &MC.monitor(&1, user_pid, {:invite, user_id}))
          |> bump()

        # don't send the updated event to the newly invited player
        for id <- Stream.concat(Map.keys(data.invited), Map.keys(data.members)) do
          Player.party_notify_updated(id, new_data)
        end

        {:keep_state, new_data, [{:reply, from, {:ok, new_data}}]}
    end
  end

  def handle_event({:call, from}, {:accept_invite, user_id, user_pid}, :running, data) do
    case Map.pop(data.invited, user_id) do
      {nil, _} ->
        {:keep_state, data, [{:reply, from, {:error, :not_invited}}]}

      {_, rest} ->
        data =
          data
          |> bump()
          |> Map.put(:invited, rest)
          |> add_member(user_id, user_pid)

        notify_updated(data)
        {:keep_state, data, [{:reply, from, {:ok, data}}]}
    end
  end

  def handle_event({:call, from}, {:decline_invite, user_id}, :running, data) do
    case Map.pop(data.invited, user_id) do
      {nil, _} ->
        {:keep_state, data, [{:reply, from, {:error, :not_invited}}]}

      {invited, rest} ->
        :timer.cancel(invited.timeout_ref)

        data =
          data
          |> Map.update!(:monitors, fn mc ->
            MC.demonitor_by_val(mc, {:invite, user_id})
          end)
          |> bump()
          |> Map.put(:invited, rest)

        notify_updated(data)

        {:keep_state, data, [{:reply, from, {:ok, data}}]}
    end
  end

  def handle_event({:call, from}, {:cancel_invite, user_id}, :running, data) do
    case Map.get(data.invited, user_id) do
      nil ->
        {:keep_state, data, [{:reply, from, {:error, :not_invited}}]}

      invite ->
        data = cancel_invite_internal(invite, data)
        {:keep_state, data, [{:reply, from, {:ok, data}}]}
    end
  end

  def handle_event({:call, from}, {:kick_user, actor_id, target_id}, :running, data) do
    member? = Map.has_key?(data.members, actor_id)
    {target, rest} = Map.pop(data.members, target_id)

    case {member?, target} do
      {false, _} ->
        {:keep_state, data, [{:reply, from, {:error, :not_a_member}}]}

      {_, nil} ->
        {:keep_state, data, [{:reply, from, {:error, :invalid_target}}]}

      {true, _member} ->
        data =
          data
          |> bump()
          |> Map.update!(:monitors, &MC.demonitor_by_val(&1, {:member, target_id}))
          |> Map.put(:members, rest)

        Player.party_notify_removed(target_id, data)
        notify_updated(data)
        {:keep_state, data, [{:reply, from, {:ok, data}}]}
    end
  end

  def handle_event({:call, from}, {:join_matchmaking_queues, _queues}, :running, data)
      when not is_nil(data.matchmaking),
      do: {:keep_state, data, [{:reply, from, {:error, :already_queued}}]}

  def handle_event({:call, from}, {:join_matchmaking_queues, queues}, :running, data) do
    members_id = Map.keys(data.members)

    result =
      Enum.reduce_while(queues, data.monitors, fn {q_id, version}, monitors ->
        case Matchmaking.party_join_queue(q_id, version, data.id, members_id) do
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
        data =
          Map.replace!(
            data,
            :monitors,
            Enum.reduce(queues, monitors, &MC.demonitor_by_val(&2, {:queue, elem(&1, 0)}))
          )

        {:keep_state, data, [{:reply, from, {:error, reason}}]}

      monitors ->
        data =
          data
          |> bump()
          |> Map.replace!(:monitors, monitors)
          |> Map.replace!(:matchmaking, %{queues: queues})

        # when entering matchmaking, "lock" the party, all invites are cancelled
        data =
          Enum.reduce(data.invited, data, fn {_user_id, invite}, data ->
            cancel_invite_internal(invite, data)
          end)

        for id <- Map.keys(data.members) do
          Player.party_notify_join_queues(id, queues, data)
        end

        {:keep_state, data, [{:reply, from, :ok}]}
    end
  end

  def handle_event({:call, from}, {:send_message, from_id, msg_content}, :running, data) do
    case Map.get(data.members, from_id) do
      nil ->
        {:keep_state, data, [{:reply, from, {:error, :invalid_request, :not_a_party_member}}]}

      _ ->
        msg =
          Messaging.new(
            msg_content,
            {:party, data.id, from_id},
            :erlang.monotonic_time(:micro_seconds)
          )

        for id <- Map.keys(data.members), id != from_id do
          Messaging.send(msg, {:player, id})
        end

        {:keep_state, data, [{:reply, from, :ok}]}
    end
  end

  def handle_event(:cast, :lost_matchmaking_queue, :running, data)
      when data.matchmaking == nil,
      do: {:keep_state, data}

  def handle_event(:cast, :lost_matchmaking_queue, :running, data) do
    monitors =
      Enum.reduce(data.matchmaking.queues, data.monitors, fn queue_id, mc ->
        MC.demonitor_by_val(mc, queue_id)
      end)

    {:keep_state, %{data | monitors: monitors, matchmaking: nil}}
  end

  def handle_event({:call, from}, {:rejoin, user_id, user_pid}, :starting_up, data) do
    if MapSet.member?(data.ids_to_rejoin, user_id) do
      data =
        data
        |> Map.update!(:ids_to_rejoin, &MapSet.delete(&1, user_id))
        |> Map.update!(:monitors, fn mc ->
          val =
            if is_map_key(data.members, user_id),
              do: {:member, user_id},
              else: {:invite, user_id}

          MC.monitor(mc, user_pid, val)
        end)

      actions = [{:reply, from, {:ok, data}}]

      if MapSet.size(data.ids_to_rejoin) == 0 do
        Logger.debug("all member rejoined, start up completed")
        {:next_state, :running, data, actions}
      else
        {:keep_state, data, actions}
      end
    else
      {:keep_state, data, [{:reply, from, {:error, :not_a_member}}]}
    end
  end

  def handle_event({:call, from}, {:rejoin, _user_id}, _state, data) do
    {:keep_state, data, [{:reply, from, {:error, :invalid_party}}]}
  end

  def handle_event(:info, {:invite_timeout, user_id}, :running, data) do
    case Map.get(data.invited, user_id) do
      nil ->
        {:keep_state, data}

      invite ->
        data = cancel_invite_internal(invite, data)
        {:keep_state, data}
    end
  end

  def handle_event(:info, {:DOWN, ref, :process, _pid, :shutdown}, state, data) do
    val = MC.get_val(data.monitors, ref)
    data = Map.update!(data, :monitors, &MC.demonitor_by_val(&1, val))

    data =
      case val do
        {:invite, user_id} when is_map_key(data.invited, user_id) ->
          Map.update!(data, :ids_to_rejoin, &MapSet.put(&1, user_id))

        {:member, user_id} when is_map_key(data.members, user_id) ->
          Map.update!(data, :ids_to_rejoin, &MapSet.put(&1, user_id))

        _ ->
          data
      end

    case state do
      :running -> {:next_state, :shutting_down, data}
      _ -> {:keep_state, data}
    end
  end

  # when the reason isn't :shutdown, assume a crash from the peer and fix state accordingly
  def handle_event(:info, {:DOWN, ref, :process, _pid, _reason}, :running, data) do
    val = MC.get_val(data.monitors, ref)
    data = Map.update!(data, :monitors, &MC.demonitor_by_val(&1, val))

    data =
      case val do
        nil ->
          data

        {:invite, user_id} ->
          Map.update!(data, :invited, &Map.delete(&1, user_id))
          |> notify_updated()

        {:member, user_id} ->
          Map.update!(data, :members, &Map.delete(&1, user_id))
          |> notify_updated()

        {:queue, _qid} ->
          %{data | matchmaking: nil}
      end

    if Enum.empty?(data.members),
      do: {:stop, :normal, data},
      else: {:keep_state, data}
  end

  def handle_event({:call, from}, _, :shutting_down, data) do
    {:keep_state, data, [{:reply, from, {:error, :party_shutting_down}}]}
  end

  def handle_event({:call, _from}, _, :starting_up, data) do
    {:keep_state, data, [:postpone]}
  end

  def handle_event(:info, _, :starting_up, data) do
    {:keep_state, data, [:postpone]}
  end

  @impl :gen_statem
  def terminate(:shutdown, :shutting_down, data) do
    # by that time, the party should have received all the :shutdown signals
    cond do
      MapSet.size(data.ids_to_rejoin) != Enum.count(data.members) + Enum.count(data.invited) ->
        Logger.warning("Missing ids to rejoin, refusing to snapshot invalid state")

      Teiserver.Tachyon.should_restore_state?() ->
        to_save =
          data
          |> Map.take([:version, :members, :ids_to_rejoin, :invited])
          |> Map.update!(:invited, fn invited ->
            Enum.map(invited, fn {user_id, invite} ->
              {user_id, Map.drop(invite, [:timeout_ref])}
            end)
            |> Map.new()
          end)
          |> :erlang.term_to_binary()

        Teiserver.KvStore.put("party", data.id, to_save)

      true ->
        nil
    end
  end

  def terminate(_reason, _state, _data), do: nil

  defp notify_updated(data) do
    for id <- Stream.concat(Map.keys(data.invited), Map.keys(data.members)) do
      Player.party_notify_updated(id, Map.drop(data, [:monitors]))
    end

    data
  end

  defp via_tuple(party_id) do
    Party.Registry.via_tuple(party_id)
  end

  defp bump(data), do: Map.update!(data, :version, &(&1 + 1))

  defp add_member(data, user_id, user_pid) do
    data =
      Map.update!(
        data,
        :members,
        &Map.put(&1, user_id, %{id: user_id, joined_at: DateTime.utc_now()})
      )

    case MC.get_ref(data.monitors, {:invite, user_id}) do
      nil ->
        Map.update!(data, :monitors, fn mc ->
          MC.monitor(mc, user_pid, {:member, user_id})
        end)

      _ref ->
        Map.update!(data, :monitors, fn mc ->
          MC.replace_val!(mc, {:invite, user_id}, {:member, user_id})
        end)
    end
  end

  defp cancel_invite_internal(invite, data) do
    :timer.cancel(invite.timeout_ref)

    data =
      data
      |> bump()
      |> Map.update!(:invited, &Map.delete(&1, invite.id))
      |> Map.update!(:monitors, &MC.demonitor_by_val(&1, {:invite, invite.id}))

    Player.party_notify_removed(invite.id, data)
    notify_updated(data)
    data
  end
end
