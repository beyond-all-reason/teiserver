defmodule Teiserver.Protocols.Tachyon.V1.PartyOut do
  alias Teiserver.Protocols.Tachyon.V1.Tachyon

  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:create, party) do
    %{
      cmd: "s.party.create",
      party: Tachyon.convert_object(party, :party_full)
    }
  end
end
