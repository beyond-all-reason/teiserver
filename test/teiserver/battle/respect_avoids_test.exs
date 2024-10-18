defmodule Teiserver.Battle.RespectAvoidsTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use ExUnit.Case
  import Mock

  @moduletag :balance_test
  alias Teiserver.Battle.Balance.RespectAvoids
  alias Teiserver.Account.RelationshipLib
  alias Teiserver.Config

  setup_with_mocks([
    {Config, [:passthrough], [get_site_config_cache: fn key -> 2 end]}
  ]) do
    :ok
  end

  test "can process expanded_group" do
    # Setup mocks with no avoids (insteading of calling db)
    with_mock(RelationshipLib,
      get_lobby_avoids: fn _player_ids, _limit, _player_limit, _minimum_time_hours -> [] end,
      get_lobby_avoids: fn _player_ids, _limit, _player_limit -> [] end
    ) do
      # https://server5.beyondallreason.info/battle/2092529/players
      expanded_group = [
        %{
          count: 2,
          members: [1, 2],
          ratings: [12.25, 13.98],
          names: ["kyutoryu", "fbots1998"],
          uncertainties: [0, 1],
          ranks: [1, 1]
        },
        %{
          count: 2,
          members: ["Dixinormus", "HungDaddy"],
          ratings: [18.28, 2.8],
          names: ["Dixinormus", "HungDaddy"],
          uncertainties: [2, 2],
          ranks: [0, 0]
        },
        %{
          count: 1,
          members: ["SLOPPYGAGGER"],
          ratings: [8.89],
          names: ["SLOPPYGAGGER"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["jauggy"],
          ratings: [20.49],
          names: ["jauggy"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["reddragon2010"],
          ratings: [18.4],
          names: ["reddragon2010"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["Aposis"],
          ratings: [20.42],
          names: ["Aposis"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["MaTThiuS_82"],
          ratings: [8.26],
          names: ["MaTThiuS_82"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["Noody"],
          ratings: [17.64],
          names: ["Noody"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["[DTG]BamBin0"],
          ratings: [20.06],
          names: ["[DTG]BamBin0"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["barmalev"],
          ratings: [3.58],
          names: ["barmalev"],
          uncertainties: [3],
          ranks: [2]
        }
      ]

      result = RespectAvoids.perform(expanded_group, 2)

      assert result.logs == [
               "------------------------------------------------------",
               "Algorithm: respect_avoids",
               "------------------------------------------------------",
               "This algorithm will try and respect parties and avoids of players so long as it can keep team rating difference within certain bounds. Parties have higher importance than avoids.",
               "Recent avoids will be ignored. New players will be spread evenly across teams and cannot be avoided.",
               "------------------------------------------------------",
               "Lobby details:",
               "Parties: (kyutoryu, fbots1998), (Dixinormus, HungDaddy)",
               "Avoid min time required: 2 h",
               "Avoids considered: 0",
               "------------------------------------------------------",
               "New players: None",
               "------------------------------------------------------",
               "Perform brute force with the following players to get the best score.",
               "Players: Dixinormus, fbots1998, kyutoryu, HungDaddy, jauggy, Aposis, [DTG]BamBin0, reddragon2010, Noody, SLOPPYGAGGER, MaTThiuS_82, barmalev",
               "------------------------------------------------------",
               "Brute force result:",
               "Team rating diff penalty: 1.7",
               "Broken party penalty: 0",
               "Broken avoid penalty: 0",
               "Stdev diff penalty: 2.9",
               "Score: 4.5 (lower is better)",
               "------------------------------------------------------",
               "Draft remaining players (ordered from best to worst).",
               "Remaining: ",
               "------------------------------------------------------",
               "Final result:",
               "Team 1: Noody, reddragon2010, HungDaddy, kyutoryu, fbots1998, Dixinormus",
               "Team 2: barmalev, MaTThiuS_82, SLOPPYGAGGER, [DTG]BamBin0, Aposis, jauggy"
             ]
    end
  end

  test "can process expanded_group with parties" do
    mock_avoid = [["jauggy", "reddragon2010"]]
    # Setup mock with 1 avoid
    with_mock(RelationshipLib,
      get_lobby_avoids: fn _player_ids, _limit, _player_limit, _minimum_time_hours ->
        mock_avoid
      end,
      get_lobby_avoids: fn _player_ids, _limit, _player_limit -> mock_avoid end
    ) do
      # https://server5.beyondallreason.info/battle/2092529/players
      expanded_group = [
        %{
          count: 2,
          members: [1, 2],
          ratings: [12.25, 13.98],
          names: ["kyutoryu", "fbots1998"],
          uncertainties: [0, 1],
          ranks: [1, 1]
        },
        %{
          count: 1,
          members: ["Dixinormus"],
          ratings: [18.28],
          names: ["Dixinormus"],
          uncertainties: [2],
          ranks: [0]
        },
        %{
          count: 1,
          members: ["HungDaddy"],
          ratings: [2.8],
          names: ["HungDaddy"],
          uncertainties: [2],
          ranks: [0]
        },
        %{
          count: 1,
          members: ["SLOPPYGAGGER"],
          ratings: [8.89],
          names: ["SLOPPYGAGGER"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["jauggy"],
          ratings: [20.49],
          names: ["jauggy"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["reddragon2010"],
          ratings: [18.4],
          names: ["reddragon2010"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["Aposis"],
          ratings: [20.42],
          names: ["Aposis"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["MaTThiuS_82"],
          ratings: [8.26],
          names: ["MaTThiuS_82"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["Noody"],
          ratings: [17.64],
          names: ["Noody"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["[DTG]BamBin0"],
          ratings: [20.06],
          names: ["[DTG]BamBin0"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["barmalev"],
          ratings: [3.58],
          names: ["barmalev"],
          uncertainties: [3],
          ranks: [2]
        }
      ]

      result = RespectAvoids.perform(expanded_group, 2)

      assert result.logs == [
               "------------------------------------------------------",
               "Algorithm: respect_avoids",
               "------------------------------------------------------",
               "This algorithm will try and respect parties and avoids of players so long as it can keep team rating difference within certain bounds. Parties have higher importance than avoids.",
               "Recent avoids will be ignored. New players will be spread evenly across teams and cannot be avoided.",
               "------------------------------------------------------",
               "Lobby details:",
               "Parties: (kyutoryu, fbots1998)",
               "Avoid min time required: 2 h",
               "Avoids considered: 1",
               "------------------------------------------------------",
               "New players: None",
               "------------------------------------------------------",
               "Perform brute force with the following players to get the best score.",
               "Players: fbots1998, kyutoryu, jauggy, reddragon2010, Aposis, [DTG]BamBin0, Dixinormus, Noody, SLOPPYGAGGER, MaTThiuS_82, barmalev, HungDaddy",
               "------------------------------------------------------",
               "Brute force result:",
               "Team rating diff penalty: 1.6",
               "Broken party penalty: 0",
               "Broken avoid penalty: 0",
               "Stdev diff penalty: 2.9",
               "Score: 4.5 (lower is better)",
               "------------------------------------------------------",
               "Draft remaining players (ordered from best to worst).",
               "Remaining: ",
               "------------------------------------------------------",
               "Final result:",
               "Team 1: HungDaddy, Noody, Dixinormus, reddragon2010, kyutoryu, fbots1998",
               "Team 2: barmalev, MaTThiuS_82, SLOPPYGAGGER, [DTG]BamBin0, Aposis, jauggy"
             ]

      # Notice in result jauggy no longer on same team as reddragon2010 due to avoidance
    end
  end

  test "gives each team the best captain" do
    # Setup mocks with no avoids (insteading of calling db)
    with_mock(RelationshipLib,
      get_lobby_avoids: fn _player_ids, _limit, _player_limit, _minimum_time_hours -> [] end,
      get_lobby_avoids: fn _player_ids, _limit, _player_limit -> [] end
    ) do
      expanded_group = [
        %{
          count: 2,
          members: ["fraqzilla", "Spaceh"],
          ratings: [4, 0],
          names: ["fraqzilla", "Spaceh"],
          uncertainties: [0, 1],
          ranks: [1, 1]
        },
        %{
          count: 1,
          members: ["[DmE]"],
          ratings: [34],
          names: ["[DmE]"],
          uncertainties: [2],
          ranks: [0]
        },
        %{
          count: 1,
          members: ["Jeff"],
          ratings: [31],
          names: ["Jeff"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["Jarial"],
          ratings: [26],
          names: ["Jarial"],
          uncertainties: [0],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["Gmans"],
          ratings: [21],
          names: ["Gmans"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["Threekey"],
          ratings: [18],
          names: ["Threekey"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["Zippo9"],
          ratings: [17],
          names: ["Zippo9"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["AcowAdonis"],
          ratings: [25],
          names: ["AcowAdonis"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["AbyssWatcher"],
          ratings: [23],
          names: ["AbyssWatcher"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["MeowCat"],
          ratings: [21],
          names: ["MeowCat"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["mighty"],
          ratings: [21],
          names: ["mighty"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["Kaa"],
          ratings: [16],
          names: ["Kaa"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["Faeton"],
          ratings: [11],
          names: ["Faeton"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["Saffir"],
          ratings: [10],
          names: ["Saffir"],
          uncertainties: [3],
          ranks: [2]
        },
        %{
          count: 1,
          members: ["Pantsu_Ripper"],
          ratings: [10],
          names: ["Pantsu_Ripper"],
          uncertainties: [3],
          ranks: [2]
        }
      ]

      result = RespectAvoids.perform(expanded_group, 2)

      assert result.logs == [
               "------------------------------------------------------",
               "Algorithm: respect_avoids",
               "------------------------------------------------------",
               "This algorithm will try and respect parties and avoids of players so long as it can keep team rating difference within certain bounds. Parties have higher importance than avoids.",
               "Recent avoids will be ignored. New players will be spread evenly across teams and cannot be avoided.",
               "------------------------------------------------------",
               "Lobby details:",
               "Parties: (fraqzilla, Spaceh)",
               "Avoid min time required: 2 h",
               "Avoids considered: 0 (Max: 6)",
               "------------------------------------------------------",
               "New players: None",
               "------------------------------------------------------",
               "Perform brute force with the following players to get the best score.",
               "Players: fraqzilla, Spaceh, [DmE], Jeff, Jarial, AcowAdonis, AbyssWatcher, Gmans, MeowCat, mighty, Threekey, Zippo9, Kaa, Faeton",
               "------------------------------------------------------",
               "Brute force result:",
               "Team rating diff penalty: 2",
               "Broken party penalty: 0",
               "Broken avoid penalty: 0",
               "Stdev diff penalty: 11.4",
               "Score: 13.4 (lower is better)",
               "------------------------------------------------------",
               "Draft remaining players (ordered from best to worst).",
               "Remaining: Saffir, Pantsu_Ripper",
               "------------------------------------------------------",
               "Final result:",
               "Team 1: Gmans, AbyssWatcher, AcowAdonis, Jarial, [DmE], Spaceh, fraqzilla, Pantsu_Ripper",
               "Team 2: Faeton, Kaa, Zippo9, Threekey, mighty, MeowCat, Jeff, Saffir"
             ]
    end
  end
end
