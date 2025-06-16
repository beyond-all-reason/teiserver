defmodule Teiserver.Account.PartyServer do
  use GenServer
  require Logger
  alias Teiserver.{Account}
  alias Phoenix.PubSub
  alias Teiserver.Data.Types, as: T

  @impl true
  def handle_call(:get_party, _from, state) do
    {:reply, state.party, state}
  end

  def handle_call({:accept_invite, userid}, _from, %{party: party} = state) do
    {result, new_party} =
      cond do
        Enum.member?(party.pending_invites, userid) ->
          Logger.debug("Accepted invite of #{userid}")
          party = add_member(userid, state)
          {{true, party}, party}

        Enum.member?(party.members, userid) ->
          Logger.debug("Declined invite of #{userid}, already a member")
          {{false, "Already a member"}, party}

        true ->
          Logger.debug("Declined invite of #{userid}, no invite found")
          {{false, "Not invited"}, party}
      end

    {:reply, result, %{state | party: new_party}}
  end

  @impl true
  def handle_cast({:create_invite, userid}, %{party: party} = state) do
    new_party =
      cond do
        Enum.member?(party.pending_invites, userid) ->
          Logger.debug("Failed create invite for #{userid}, existing invite")
          party

        Enum.member?(party.members, userid) ->
          Logger.debug("Failed create invite for #{userid}, existing member")
          party

        true ->
          Logger.debug("Created invite for #{userid}")
          new_invites = [userid | party.pending_invites] |> Enum.uniq()

          PubSub.broadcast(
            Teiserver.PubSub,
            "teiserver_party:#{party.id}",
            %{
              channel: "teiserver_party:#{party.id}",
              event: :updated_values,
              party_id: party.id,
              new_values: %{pending_invites: new_invites},
              operation: {:invite_created, userid}
            }
          )

          PubSub.broadcast(
            Teiserver.PubSub,
            "teiserver_client_messages:#{userid}",
            %{
              channel: "teiserver_client_messages:#{userid}",
              event: :party_invite,
              party_id: party.id,
              members: party.members,
              pending_invites: party.pending_invites
            }
          )

          %{party | pending_invites: new_invites}
      end

    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:cancel_invite, userid}, %{party: party} = state) do
    new_party =
      cond do
        Enum.member?(party.pending_invites, userid) ->
          Logger.debug("Cancelled invite for #{userid}")

          new_invites = List.delete(party.pending_invites, userid)

          PubSub.broadcast(
            Teiserver.PubSub,
            "teiserver_party:#{party.id}",
            %{
              channel: "teiserver_party:#{party.id}",
              event: :updated_values,
              party_id: party.id,
              new_values: %{pending_invites: new_invites},
              operation: {:invite_cancelled, [userid]}
            }
          )

          %{party | pending_invites: new_invites}

        true ->
          Logger.debug("Failed cancel invite for #{userid}, not a member")
          party
      end

    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:member_leave, userid}, %{party: party} = state) do
    new_party =
      cond do
        not Enum.member?(party.members, userid) ->
          Logger.debug("Failed member leave for #{userid}, not a member")
          party

        # Last member leaving, close the party down
        party.members == [userid] ->
          Logger.debug("Member left #{userid}, last member, stopping party")

          PubSub.broadcast(
            Teiserver.PubSub,
            "teiserver_party:#{party.id}",
            %{
              channel: "teiserver_party:#{party.id}",
              event: :updated_values,
              party_id: party.id,
              new_values: %{pending_invites: []},
              operation: {:invite_cancelled, party.pending_invites}
            }
          )

          PubSub.broadcast(
            Teiserver.PubSub,
            "teiserver_party:#{party.id}",
            %{
              channel: "teiserver_party:#{party.id}",
              event: :closed,
              party_id: party.id,
              reason: "No members",
              last_member: userid
            }
          )

          Teiserver.Account.PartyLib.stop_party_server(party.id)
          party

        true ->
          Logger.debug("Member left for #{userid}")
          remove_member(userid, state)
      end

    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:kick_member, userid}, %{party: party} = state) do
    new_party =
      cond do
        Enum.member?(party.members, userid) ->
          Logger.debug("Kicking member #{userid}")
          remove_member(userid, state)

        true ->
          Logger.debug("Failed to kicking member #{userid}, not a member")
          party
      end

    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:new_leader, userid}, %{party: party} = state) do
    new_party =
      cond do
        party.leader == userid ->
          party

        not Enum.member?(party.members, userid) ->
          party

        true ->
          PubSub.broadcast(
            Teiserver.PubSub,
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

  def handle_cast({:add_member, userid}, state) do
    new_party = add_member(userid, state)
    {:noreply, %{state | party: new_party}}
  end

  @impl true
  def handle_info(%{channel: "teiserver_client_messages:" <> userid, event: :disconnected}, state) do
    {:noreply, %{state | party: remove_member(String.to_integer(userid), state)}}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _}, state) do
    {:noreply, state}
  end

  @spec add_member(T.userid(), map()) :: map()
  def add_member(userid, %{party: party} = _state) do
    new_invites = List.delete(party.pending_invites, userid)
    new_members = [userid | party.members] |> Enum.uniq()

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_party:#{party.id}",
      %{
        channel: "teiserver_party:#{party.id}",
        event: :updated_values,
        party_id: party.id,
        new_values: %{pending_invites: new_invites, members: new_members},
        operation: {:member_added, userid}
      }
    )

    PubSub.unsubscribe(Teiserver.PubSub, "teiserver_client_messages:#{userid}")
    PubSub.subscribe(Teiserver.PubSub, "teiserver_client_messages:#{userid}")

    Account.move_client_to_party(userid, party.id)

    %{party | pending_invites: new_invites, members: new_members}
  end

  @spec remove_member(T.userid(), map()) :: map()
  def remove_member(userid, %{party: party} = _state) do
    new_members = List.delete(party.members, userid)

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_party:#{party.id}",
      %{
        channel: "teiserver_party:#{party.id}",
        event: :updated_values,
        party_id: party.id,
        new_values: %{members: new_members},
        operation: {:member_removed, userid}
      }
    )

    new_leader =
      if party.leader == userid and not Enum.empty?(new_members) do
        hd(Enum.reverse(new_members))
      else
        party.leader
      end

    # We grab the longest serving member for the new leader
    PubSub.unsubscribe(Teiserver.PubSub, "teiserver_client_messages:#{userid}")
    Account.move_client_to_party(userid, nil)

    if Enum.empty?(new_members) do
      Teiserver.Account.PartyLib.stop_party_server(party.id)
    end

    %{party | members: new_members, leader: new_leader}
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(map()) :: {:ok, map()}
  def init(%{party: %{id: id} = party}) do
    Horde.Registry.register(
      Teiserver.PartyRegistry,
      id,
      id
    )

    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_client_messages:#{party.leader}")

    Account.move_client_to_party(party.leader, party.id)
    Logger.metadata(request_id: "PartyServer##{id}")
    Logger.debug("Started PartyServer")

    {:ok, %{party: party}}
  end
end
