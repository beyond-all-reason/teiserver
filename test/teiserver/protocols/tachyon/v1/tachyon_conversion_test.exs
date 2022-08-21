defmodule Teiserver.Protocols.V1.TachyonConversionTest do
  use Central.DataCase
  alias Teiserver.Protocols.Tachyon.V1.Tachyon

  test "convert lobby" do
    lobby = %{
      name: "Tachyon lobby conversion test",
      nattype: "none",
      port: 1234,
      game_hash: "string_of_characters",
      map_hash: "string_of_characters",
      map_name: "koom valley",
      game_name: "BAR",
      engine_name: "spring-105",
      engine_version: "105.1.2.3",
      password: "word",
      passworded: true,
      settings: %{
        max_players: 12
      }
    }

    assert Tachyon.convert_object(lobby, :lobby) == %{
      engine_name: "spring-105",
      engine_version: "105.1.2.3",
      map_hash: "string_of_characters",
      map_name: "koom valley",
      game_name: "BAR",
      name: "Tachyon lobby conversion test",
      passworded: true,
      settings: %{max_players: 12},
      port: 1234
    }
  end
end
