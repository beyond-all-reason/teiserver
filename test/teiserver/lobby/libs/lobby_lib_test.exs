defmodule Teiserver.Lobby.LobbyLibTest do
  alias Teiserver.Lobby.LobbyLib

  use Teiserver.DataCase, async: true

  describe "validate_name" do
    test "rejects empty name" do
      assert {:error, _msg} = LobbyLib.validate_name("")
    end

    test "rejects name over character limit" do
      limit = LobbyLib.max_name_length()
      result = String.duplicate("a", limit + 1) |> LobbyLib.validate_name()

      assert {:error, _msg} = result
    end

    test "rejects name with invalid characters" do
      assert {:error, _msg} = LobbyLib.validate_name("invalid char: =")
    end
  end
end
