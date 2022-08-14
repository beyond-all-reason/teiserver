defmodule Teiserver.Protocols.Tachyon.V1.PartyIn do
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  alias Teiserver.{Account}
  alias Teiserver.Account.PartyLib

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("create", _, state) do
    party = Account.create_party(state.userid)
    send(self(), {:action, {:lead_party, party.id}})
    reply(:party, :create, party, state)
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
    if state.party_id != nil and state.party_role == :leader do
      Account.create_party_invite(state.party_id, userid)
    end
    state
  end

  def do_handle("accept", %{"party_id" => party_id}, state) do
    case Account.accept_party_invite(party_id, state.userid) do
      {true, party} ->
        send(self(), {:action, {:join_party, party.id}})
        reply(:party, :accept, {true, party}, state)

      {false, reason} ->
        reply(:party, :accept, {false, reason}, state)

      nil ->
        reply(:party, :accept, {false, "No party found"}, state)
    end
    state
  end

  def do_handle("decline", _, state) do
    reply(:party, :create, nil, state)
  end

  def do_handle("kick", _, state) do
    reply(:party, :create, nil, state)
  end

  def do_handle("new_leader", _, state) do
    reply(:party, :create, nil, state)
  end

  def do_handle("leave", _, state) do
    reply(:party, :create, nil, state)
  end

  def do_handle("message", _, %{party_id: nil} = state) do
    state
  end

  def do_handle("message", %{"message" => message}, state) do
    PartyLib.say(state.userid, state.party_id, message)
    state
  end
end
