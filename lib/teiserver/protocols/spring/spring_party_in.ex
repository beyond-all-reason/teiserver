defmodule Teiserver.Protocols.Spring.PartyIn do
  alias Teiserver.Protocols.SpringOut
  alias Teiserver.Account

  @spec do_handle(String.t(), String.t(), String.t() | nil, map()) :: map()
  def do_handle("create_new_party", _, msg_id, state) when not is_nil(state.party_id) do
    # bit meh to do that in the protocol layer, but there isn't really another
    # place, and the whole thing is EOL
    SpringOut.reply(
      :no,
      {"c.party.create_new_party", "msg=Already in a party"},
      msg_id,
      state
    )
  end

  def do_handle("create_new_party", _, msg_id, state) do
    party =
      Account.create_party(state.user.id)

    SpringOut.reply(
      :okay,
      {"c.party.create_new_party", "party_id=#{party.id}"},
      msg_id,
      state |> Map.put(:party_id, party.id)
    )
  end
end
