defmodule Teiserver.Party.PartyTest do
  alias Teiserver.Party
  alias Teiserver.Support.Polling

  use Teiserver.DataCase

  @moduletag :tachyon

  test "create party" do
    assert {:ok, %{id: party_id}} = Party.create_party(123)
    Polling.poll_until_some(fn -> Party.lookup(party_id) end)
  end
end
