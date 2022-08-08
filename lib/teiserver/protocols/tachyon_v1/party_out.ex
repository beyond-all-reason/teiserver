defmodule Teiserver.Protocols.Tachyon.V1.PartyOut do
  alias Teiserver.Protocols.Tachyon.V1.Tachyon

  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:create, party) do
    %{
      cmd: "s.party.create",
      party: Tachyon.convert_object(party, :party_full)
    }
  end

  def do_reply(:info, party) do
    %{
      cmd: "s.party.info",
      party: Tachyon.convert_object(party, :party)
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
end
