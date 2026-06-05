defmodule Teiserver.Lobby.LobbyLibTest do
  alias Teiserver.Lobby.LobbyLib

  use Teiserver.DataCase, async: true

  import Teiserver.LobbyFixtures, only: [invalid_name: 1]

  describe "validate_name" do
    test "rejects empty name" do
      assert {:error, _msg} = invalid_name(:empty) |> LobbyLib.validate_name()
    end

    test "rejects name over character limit" do
      assert {:error, _msg} = invalid_name(:too_long) |> LobbyLib.validate_name()
    end

    test "rejects name with invalid characters" do
      assert {:error, _msg} = invalid_name(:invalid_char) |> LobbyLib.validate_name()
    end

    test "rejects name with flagged words" do
      assert {:error, _msg} = invalid_name(:flagged) |> LobbyLib.validate_name()
    end
  end
end
