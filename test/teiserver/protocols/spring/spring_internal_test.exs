defmodule Teiserver.SpringInternalTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.Protocols.Spring

  test "parse and create loop - clientstatus" do
    statuses = ~w(1 4 16 25)

    for s <- statuses do
      result =
        s
        |> Spring.parse_client_status()
        |> Spring.create_client_status()
        |> to_string()

      assert s == result, message: "Status #{s}, got: #{result}"
    end
  end

  test "parse and create loop - battlestatus" do
    statuses = ~w(4195330 4195418 4195462 4195402)

    for s <- statuses do
      result =
        s
        |> Spring.parse_battle_status()
        |> Spring.create_battle_status()
        |> to_string()

      assert s == result, message: "Status #{s}, got: #{result}"
    end
  end

  test "parse_battle_status" do
    # Test spectator
    player_status = ~w(4195330 4195418 4195462 4195402)
    spectator_status = ~w(0 4194374 4194370 4194304)

    for s <- player_status do
      result = Spring.parse_battle_status(s)
      assert result.player == true, message: "Status #{s}"
    end

    for s <- spectator_status do
      result = Spring.parse_battle_status(s)
      assert result.player == false, message: "Status #{s}"
    end

    # Ally team value, need to check these are actually right
    # since some of them seem to come up with different team numbers
    team0_status = ~w(4195330)
    team1_status = ~w(4195394)
    team2_status = ~w(4195458)
    team3_status = ~w(4195522)

    for s <- team0_status do
      result = Spring.parse_battle_status(s)
      assert result.player == true, message: "Status #{s}"
      assert result.team_number == 0, message: "Status #{s}"
    end

    for s <- team1_status do
      result = Spring.parse_battle_status(s)
      assert result.player == true, message: "Status #{s}"
      assert result.team_number == 1, message: "Status #{s}"
    end

    for s <- team2_status do
      result = Spring.parse_battle_status(s)
      assert result.player == true, message: "Status #{s}"
      assert result.team_number == 2, message: "Status #{s}"
    end

    for s <- team3_status do
      result = Spring.parse_battle_status(s)
      assert result.player == true, message: "Status #{s}"
      assert result.team_number == 3, message: "Status #{s}"
    end

    # Faction selector
    armarda_status = ~w(4195522 4195330)
    core_status = ~w(20972546)
    random_status = ~w(37749760)

    for s <- armarda_status do
      result = Spring.parse_battle_status(s)
      assert result.side == 0, message: "Status #{s}"
    end

    for s <- core_status do
      result = Spring.parse_battle_status(s)
      assert result.side == 1, message: "Status #{s}"
    end

    for s <- random_status do
      result = Spring.parse_battle_status(s)
      assert result.side == 2, message: "Status #{s}"
    end

    # Handicap
    handicaps = [
      {"4195522", 0},
      {"4400130", 100},
      {"4240386", 22}
    ]

    for {s, expected} <- handicaps do
      result = Spring.parse_battle_status(s)
      assert result.handicap == expected, message: "Status #{s}"
    end
  end
end
