defmodule Teiserver.Protocols.Tachyon.V1.PartyIn do
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  alias Teiserver.{Account}
  alias Teiserver.Account.PartyLib

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("create", _, state) do
    party = Account.create_party(state.userid)
    send(self(), {:action, {:lead_party, party.id}})
    # reply(:party, :added_to, party.id, state)
    state
  end

  def do_handle("info", %{"party_id" => party_id}, state) do
    case Account.get_party(party_id) do
      nil ->
        reply(:party, :info_public, nil, state)

      party ->
        full_info = Enum.member?(party.pending_invites ++ party.members, state.userid)

        if full_info do
          reply(:party, :info_full, party, state)
        else
          reply(:party, :info_public, party, state)
        end
    end
  end

  def do_handle("invite", %{"userid" => userid}, state) do
    if state.party_id != nil do
      Account.create_party_invite(state.party_id, userid)
    end

    state
  end

  def do_handle("cancel", %{"userid" => userid}, state) do
    if state.party_id != nil and state.party_role == :leader do
      Account.cancel_party_invite(state.party_id, userid)
    end

    state
  end

  # Accepting when not a member of a party
  def do_handle("accept", %{"party_id" => party_id}, %{party_id: nil} = state) do
    case Account.accept_party_invite(party_id, state.userid) do
      {true, party} ->
        send(self(), {:action, {:join_party, party.id}})
        state

      {false, reason} ->
        reply(:party, :accept, {false, reason}, state)

      nil ->
        reply(:party, :accept, {false, "No party found"}, state)
    end

    state
  end

  def do_handle("accept", %{"party_id" => party_id}, %{party_id: existing_party_id} = state) do
    case Account.accept_party_invite(party_id, state.userid) do
      {true, party} ->
        send(self(), {:action, {:leave_party, existing_party_id}})
        PartyLib.cast_party(existing_party_id, {:member_leave, state.userid})

        send(self(), {:action, {:join_party, party.id}})
        state

      {false, reason} ->
        reply(:party, :accept, {false, reason}, state)

      nil ->
        reply(:party, :accept, {false, "No party found"}, state)
    end

    state
  end

  def do_handle("decline", %{"party_id" => party_id}, state) do
    PartyLib.cast_party(party_id, {:cancel_invite, state.userid})
    state
  end

  # Past this point if they're not in a party don't even bother doing anything
  def do_handle(_, _, %{party_id: nil} = state) do
    state
  end

  def do_handle("kick", %{"user_id" => user_id}, state) when is_integer(user_id) do
    party = Account.get_party(state.party_id)

    if state.userid == party.leader do
      Account.kick_user_from_party(state.party_id, user_id)
    end
  end

  def do_handle("new_leader", %{"user_id" => user_id}, state) when is_integer(user_id) do
    party = Account.get_party(state.party_id)

    if state.userid == party.leader do
      PartyLib.cast_party(state.party_id, {:new_leader, user_id})
    end

    state
  end

  def do_handle("leave", _, state) do
    PartyLib.cast_party(state.party_id, {:member_leave, state.userid})
    Account.move_client_to_party(state.userid, nil)
    send(self(), {:action, {:leave_party, state.party_id}})
    state
  end

  def do_handle("message", %{"message" => message}, state) do
    PartyLib.say(state.userid, state.party_id, message)
    state
  end
end
