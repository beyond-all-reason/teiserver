defmodule Teiserver.Account.PartyServer do
  use GenServer
  require Logger
  # alias Teiserver.{Account}
  alias Phoenix.PubSub

  @impl true
  def handle_call(:get_party_state, _from, state) do
    {:reply, state.party, state}
  end

  @impl true
  def handle_cast({:add_invite, userid}, %{party: party} = state) do
    new_party = cond do
      Enum.member?(party.pending_invites, userid) -> party
      Enum.member?(party.members, userid) -> party
      true ->
        PubSub.broadcast(
          Central.PubSub,
          "party:#{party.id}",
          {:party, :add_invite, party.id, userid}
        )

        new_invites = [userid | party.pending_invites] |> Enum.uniq
        %{party | pending_invites: new_invites}
    end
    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:cancel_invite, userid}, %{party: party} = state) do
    new_party = cond do
      Enum.member?(party.pending_invites, userid) ->
        PubSub.broadcast(
          Central.PubSub,
          "party:#{party.id}",
          {:party, :cancel_invite, party.id, userid}
        )

        new_invites = List.delete(party.pending_invites, userid)
        %{party | pending_invites: new_invites}

      true -> party
    end
    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:accept_invite, userid}, %{party: party} = state) do
    new_party = cond do
      Enum.member?(party.pending_invites, userid) ->
        PubSub.broadcast(
          Central.PubSub,
          "party:#{party.id}",
          {:party, :accept_invite, party.id, userid}
        )

        new_invites = List.delete(party.pending_invites, userid)
        new_members = [userid | party.members] |> Enum.uniq
        %{party | pending_invites: new_invites, members: new_members}

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
          "party:#{party.id}",
          {:party, :closed, party.id, "No members"}
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
          "party:#{party.id}",
          {:party, :new_leader, party.id, new_leader}
        )

        PubSub.broadcast(
          Central.PubSub,
          "party:#{party.id}",
          {:party, :member_leave, party.id, userid}
        )

        %{party | members: new_members, leader: new_leader}

      true ->
        new_members = List.delete(party.members, userid)

        PubSub.broadcast(
          Central.PubSub,
          "party:#{party.id}",
          {:party, :member_leave, party.id, userid}
        )

        %{party | members: new_members}

    end
    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:kick_member, userid}, %{party: party} = state) do
    new_party = cond do
      Enum.member?(party.members, userid) ->
        PubSub.broadcast(
          Central.PubSub,
          "party:#{party.id}",
          {:party, :kick_member, party.id, userid}
        )

        new_members = List.delete(party.members, userid)
        %{party | members: new_members}

      true -> party
    end
    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:new_leader, userid}, %{party: party} = state) do
    new_party = cond do
      party.leader == userid -> party
      not Enum.member?(party.members, userid) -> party
      true ->
        PubSub.broadcast(
          Central.PubSub,
          "party:#{party.id}",
          {:party, :new_leader, party.id, userid}
        )
        %{party | leader: userid}
    end
    {:noreply, %{state | party: new_party}}
  end

  def handle_cast({:update_party, new_party}, state) do
    {:noreply, %{state | party: new_party}}
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(data = %{party: %{id: id}}) do
    Horde.Registry.register(
      Teiserver.PartyRegistry,
      id,
      id
    )

    {:ok, %{party: data.party}}
  end
end
