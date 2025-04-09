defmodule Teiserver.Party.PartyTest do
  use Teiserver.DataCase

  @moduletag :tachyon

  alias Teiserver.Party
  alias Teiserver.Support.Polling

  test "create party" do
    assert {party_id, {:ok, _pid}} = Party.create_party()
    Polling.poll_until_some(fn -> Party.lookup(party_id) end)
  end
end
