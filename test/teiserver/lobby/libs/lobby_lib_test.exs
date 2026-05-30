defmodule Teiserver.Lobby.LobbyLibTest do
  alias Teiserver.Lobby.LobbyLib

  use Teiserver.DataCase, async: true

  test "name_length_valid? rejects name over character limit" do
    limit = LobbyLib.max_name_length()
    result = String.duplicate("a", limit + 1) |> LobbyLib.name_length_valid?()

    assert not result
  end
end
