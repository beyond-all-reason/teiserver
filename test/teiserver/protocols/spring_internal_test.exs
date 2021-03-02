defmodule Teiserver.SpringInternalTest do
  use Central.DataCase, async: true
  alias Teiserver.Protocols.SpringProtocol

  test "parse and create loop" do
    statuses = ~w(4195330 4195418 4195462 4195402)

    for s <- statuses do
      result = s
      |> SpringProtocol.parse_battle_status
      |> SpringProtocol.create_battle_status
      |> to_string

      assert s == result, message: "Status #{s}, got: #{result}"
    end
  end

  test "parse_battle_status" do
    # Test spectator
    player_status = ~w(4195330 4195418 4195462 4195402)
    spectator_status = ~w(0 4194374 4194370)

    for s <- player_status do
      result = SpringProtocol.parse_battle_status(s)
      assert result.player == true, message: "Status #{s}"
    end

    for s <- spectator_status do
      result = SpringProtocol.parse_battle_status(s)
      assert result.player == false, message: "Status #{s}"
    end

    # Ally team value, need to check these are actually right
    # since some of them seem to come up with different team numbers
    # team1_status = ~w(4195330 4195330 4195334)
    # team2_status = ~w(4195418 4195462 4195406 4195394)
    # team3_status = ~w(4195402 4195470 4195458)
    # team4_status = ~w(4195522)

    # for s <- team1_status do
    #   result = SpringProtocol.parse_battle_status(s)
    #   IO.inspect {result.team_number, result.ally_team_number}
    # end

    # for s <- team2_status do
    #   result = SpringProtocol.parse_battle_status(s)
    #   IO.inspect {result.team_number, result.ally_team_number}
    # end

    # for s <- team3_status do
    #   result = SpringProtocol.parse_battle_status(s)
    #   IO.inspect {result.team_number, result.ally_team_number}
    # end

    # for s <- team4_status do
    #   result = SpringProtocol.parse_battle_status(s)
    #   IO.inspect {result.team_number, result.ally_team_number}
    # end

    # Faction selector
    armarda_status = ~w(4195522 4195330)
    core_status = ["20972546"]
    random_status = ["37749760"]

    for s <- armarda_status do
      result = SpringProtocol.parse_battle_status(s)
      assert result.side == 0, message: "Status #{s}"
    end

    for s <- core_status do
      result = SpringProtocol.parse_battle_status(s)
      assert result.side == 1, message: "Status #{s}"
    end

    for s <- random_status do
      result = SpringProtocol.parse_battle_status(s)
      assert result.side == 2, message: "Status #{s}"
    end

    # Handicap
    handicaps = [
      {"4195522", 0},
      {"4400130", 100},
      {"4240386", 22}
    ]
    for {s, expected} <- handicaps do
      result = SpringProtocol.parse_battle_status(s)
      assert result.handicap == expected, message: "Status #{s}"
    end
  end
end
