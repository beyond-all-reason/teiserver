defmodule Teiserver.Protocols.Spring.PartyOut do
  require Logger

  @spec do_reply(atom(), nil | String.t() | tuple() | list(), map()) :: String.t()
  def do_reply(:invited_to_party, {party_id, username}, _state) do
    "s.party.invited_to_party #{party_id} #{username}\n"
  end

  def do_reply(:invited_to_party, party_id, state) do
    "s.party.invited_to_party #{party_id} #{state.user.name}\n"
  end

  def do_reply(:member_added, {party_id, username}, _state) do
    "s.party.joined_party #{party_id} #{username}\n"
  end

  def do_reply(:invite_cancelled, {party_id, username}, _state) do
    "s.party.invite_cancelled #{party_id} #{username}\n"
  end

  def do_reply(:member_removed, {party_id, username}, _state) do
    "s.party.left_party #{party_id} #{username}\n"
  end

  def do_reply(event, data, _state) do
    Logger.error("No handler for event `#{event}` with data #{inspect(data)}")
    "\n"
  end
end
