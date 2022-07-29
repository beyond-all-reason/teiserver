defmodule Teiserver.Protocols.Tachyon.V1.PartyIn do
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  alias Teiserver.Account

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("create", _, state) do
    party = Account.create_party(state.userid)
    reply(:party, :create, party, state)
  end
end
