defmodule Teiserver.Protocols.Tachyon.V1.PartyOut do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Protocols.Tachyon.V1.Tachyon

  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:create, party) do
    %{
      cmd: "s.party.create",
      party: Tachyon.convert_object(party, :party_full)
    }
  end

  def do_reply(:info_public, party) do
    %{
      cmd: "s.party.info",
      party: Tachyon.convert_object(party, :party_public)
    }
  end

  def do_reply(:info_full, party) do
    %{
      cmd: "s.party.info",
      party: Tachyon.convert_object(party, :party_full)
    }
  end

  def do_reply(:updated, {party_id, new_values}) do
    %{
      cmd: "s.party.updated",
      party_id: party_id,
      new_values: new_values
    }
  end

  def do_reply(:invite, party_id) do
    party = Account.get_party(party_id)

    %{
      cmd: "s.party.invite",
      party: Tachyon.convert_object(party, :party_full)
    }
  end

  def do_reply(:accept, {true, party}) do
    %{
      cmd: "s.party.accept",
      result: "accepted",
      party: Tachyon.convert_object(party, :party_full)
    }
  end

  def do_reply(:accept, {false, reason}) do
    %{
      cmd: "s.party.accept",
      result: "failure",
      reason: reason
    }
  end

  def do_reply(:message, {sender_id, message}) when is_integer(sender_id) do
    %{
      cmd: "s.party.message",
      sender_id: sender_id,
      message: message
    }
  end
end
