defmodule Teiserver.Account.PartyServer do
  use GenServer
  require Logger
  alias Teiserver.{Account}
  alias Teiserver.Data.Matchmaking
  alias Phoenix.PubSub

  @impl true
  def handle_call(:get_party, _from, state) do
    {:reply, state.party, state}
  end

  def handle_call({:accept_invite, userid}, _from, %{party: party} = state) do
    {result, new_party} = cond do
      Enum.member?(party.pending_invites, userid) ->
        new_invites = List.delete(party.pending_invites, userid)
        new_members = [userid | party.members] |> Enum.uniq

        PubSub.broadcast(
          Central.PubSub,
          "teiserver_party:#{party.id}",
          %{
            channel: "teiserver_party:#{party.id}",
            event: :updated_values,
            party_id: party.id,
            new_values: %{pending_invites: new_invites, members: new_members}
          }
        )

        Account.move_client_to_party(userid, party.id)

        # Now leave any queues we were in
        party.queues
          |> Enum.each(fn queue_id ->
            Matchmaking.remove_group_from_queue(queue_id, party.id)
          end)

        party = %{party |
          pending_invites: new_invites,
          members: new_members,
          queues: []
        }

        {{true, party}, party}

      Enum.member?(party.members, userid) ->
        {{false, "Already a member"}, party}

      true ->
        {{false, "Not invited"}, party}
    end
    {:reply, result, %{state | party: new_party}}
  end

  @impl true
  def handle_cast({:create_invite, userid}, %{party: party} = state) do
    new_party = cond do
      Enum.member?(party.pending_invites, userid) -> party
      Enum.member?(party.members, userid) -> party
      true ->
        new_invites = [userid | party.pending_invites] |> Enum.uniq

        PubSub.broadcast(
          Central.PubSub,
          "teiserver_party:#{party.id}",
          %{
            channel: "teiserver_party:#{party.id}",
            event: :updated_values,
            party_id: party.id,
            new_values: %{pending_invites: new_invites}
          }
        )

        PubSub.broadcast(
          Central.PubSub,
          "teiserver_client_messages:#{userid}",
          %{
            channel: "teiserver_client_messages:#{userid}",
            event: :party_invite,
            party_id: party.id
          }
        )

        %{party | pending_invites: new_invites}
    end
    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:cancel_invite, userid}, %{party: party} = state) do
    new_party = cond do
      Enum.member?(party.pending_invites, userid) ->
        new_invites = List.delete(party.pending_invites, userid)
        PubSub.broadcast(
          Central.PubSub,
          "teiserver_party:#{party.id}",
          %{
            channel: "teiserver_party:#{party.id}",
            event: :updated_values,
            party_id: party.id,
            new_values: %{pending_invites: new_invites}
          }
        )

        %{party | pending_invites: new_invites}

      true -> party
    end
    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:member_leave, userid}, %{party: party} = state) do
    new_party = cond do
      not Enum.member?(party.members, userid) -> party

      # Last member leaving, close the party down
      party.members == [userid] ->
        PubSub.broadcast(
          Central.PubSub,
          "teiserver_party:#{party.id}",
          %{
            channel: "teiserver_party:#{party.id}",
            event: :closed,
            party_id: party.id,
            reason: "No members"
          }
        )

        Teiserver.Account.PartyLib.stop_party_server(party.id)
        party

      # Leader leaving, pick a new leader
      party.leader == userid ->
        new_members = List.delete(party.members, userid)

        # We grab the longest serving member for the new leader
        new_leader = hd(Enum.reverse(new_members))

        PubSub.broadcast(
          Central.PubSub,
          "teiserver_party:#{party.id}",
          %{
            channel: "teiserver_party:#{party.id}",
            event: :updated_values,
            party_id: party.id,
            new_values: %{leader: new_leader, members: new_members}
          }
        )

        %{party | members: new_members, leader: new_leader}

      true ->
        new_members = List.delete(party.members, userid)

        PubSub.broadcast(
          Central.PubSub,
          "teiserver_party:#{party.id}",
          %{
            channel: "teiserver_party:#{party.id}",
            event: :updated_values,
            party_id: party.id,
            new_values: %{members: new_members}
          }
        )

        %{party | members: new_members}
    end

    # Now leave any queues we were in
    party.queues
      |> Enum.each(fn queue_id ->
        Matchmaking.remove_group_from_queue(queue_id, party.id)
      end)

    new_party = %{new_party | queues: []}

    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:kick_member, userid}, %{party: party} = state) do
    new_party = cond do
      Enum.member?(party.members, userid) ->
        new_members = List.delete(party.members, userid)
        PubSub.broadcast(
          Central.PubSub,
          "teiserver_party:#{party.id}",
          %{
            channel: "teiserver_party:#{party.id}",
            event: :updated_values,
            party_id: party.id,
            new_values: %{members: new_members}
          }
        )

        Account.move_client_to_party(userid, nil)

        if Enum.empty?(new_members) do
          Teiserver.Account.PartyLib.stop_party_server(party.id)
        end

        %{party | members: new_members}

      true -> party
    end

    # Now leave any queues we were in
    party.queues
      |> Enum.each(fn queue_id ->
        Matchmaking.remove_group_from_queue(queue_id, party.id)
      end)

    new_party = %{new_party | queues: []}

    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:new_leader, userid}, %{party: party} = state) do
    new_party = cond do
      party.leader == userid ->
        party

      not Enum.member?(party.members, userid) ->
        party

      true ->
        PubSub.broadcast(
          Central.PubSub,
          "teiserver_party:#{party.id}",
          %{
            channel: "teiserver_party:#{party.id}",
            event: :updated_values,
            party_id: party.id,
            new_values: %{leader: userid}
          }
        )
        %{party | leader: userid}
    end
    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:join_queue, queue_id}, %{party: party} = state) do
    {:noreply, %{state | party: %{party | queues: [queue_id | party.queues]}}}
  end

  def handle_cast({:leave_queue, queue_id}, %{party: party} = state) do
    {:noreply, %{state | party: %{party | queues: List.delete(party.queues, queue_id)}}}
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(%{party: %{id: id} = party}) do
    Horde.Registry.register(
      Teiserver.PartyRegistry,
      id,
      id
    )

    Account.move_client_to_party(party.leader, party.id)

    {:ok, %{party: party}}
  end
end
