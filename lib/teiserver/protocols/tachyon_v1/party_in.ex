defmodule Teiserver.Protocols.Tachyon.V1.PartyIn do
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  alias Teiserver.Account

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("create", _, state) do
    party = Account.create_party(state.userid)
    send(self(), {:action, {:lead_party, party.id}})
    reply(:party, :create, party, state)
  end

  def do_handle("info", %{"party_id" => party_id}, state) do
    case Account.get_party(party_id) do
      nil ->
        reply(:party, :info, nil, state)
      party ->
        if state.party_id == party_id do
          reply(:party, :info_full, party, state)
        else
          reply(:party, :info, party, state)
        end
    end
  end

  def do_handle("invite", %{"userid" => userid}, state) do
    if state.party_id != nil and state.party_role == :leader do
      Account.create_party_invite(state.party_id, userid)
    end
    state
  end

  def do_handle("accept", _, state) do
    reply(:party, :create, nil, state)
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

  def do_handle("message", _, state) do
    reply(:party, :create, nil, state)
  end
end
