defmodule Teiserver.Party.PartyTest do
  use Teiserver.DataCase

  @moduletag :tachyon

  alias Teiserver.Party
  alias Teiserver.Support.Polling

  test "create party" do
    assert {:ok, party_id} = Party.create_party(123)
    Polling.poll_until_some(fn -> Party.lookup(party_id) end)
  end
end
