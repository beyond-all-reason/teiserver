defmodule Teiserver.Lobby.LobbyLibTest do
  alias Teiserver.Lobby.LobbyLib

  use Teiserver.DataCase, async: true

  describe "validate_name" do
    test "rejects empty name" do
      assert {:error, _msg} = LobbyLib.validate_name("")
    end

    test "rejects name over character limit" do
      name = String.duplicate("a", LobbyLib.max_name_length() + 1)
      assert {:error, _msg} = LobbyLib.validate_name(name)
    end

    test "rejects name with invalid characters" do
      assert {:error, _msg} = LobbyLib.validate_name("invalid: =")
    end

    test "rejects name with flagged words" do
      assert {:error, _msg} = LobbyLib.validate_name("cun7")
    end
  end
end
