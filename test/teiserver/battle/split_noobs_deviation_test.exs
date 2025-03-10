defmodule Teiserver.Battle.SplitNoobsDeviationTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use Teiserver.DataCase, async: false
  @moduletag :balance_test
  alias Teiserver.Battle.Balance.SplitNoobs
  alias Teiserver.Battle.BalanceLib

  test "can get reasonable deviation" do
    # https://openskill-test.web.app/single?replay=64eceb66601a3dad2be3c0784beb2c1e
    # This game showed a high deviation 34% in chobby
    # https://discord.com/channels/549281623154229250/1275366409722925056/1286261827738538035
    # However, after using adjusted ratings for newish players, this now gives a lower deviation
    expanded_group = [
      %{
        count: 1,
        members: ["Devilsreborn"],
        ratings: [22.69],
        names: ["Devilsreborn"],
        uncertainties: [7.83],
        ranks: [0]
      },
      %{
        count: 1,
        members: ["InvisibleMan"],
        ratings: [22.22],
        names: ["InvisibleMan"],
        uncertainties: [8.05],
        ranks: [0]
      },
      %{
        count: 1,
        members: ["Yotap"],
        ratings: [17.92],
        names: ["Yotap"],
        uncertainties: [8.22],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Bluto"],
        ratings: [16.70],
        names: ["Bluto"],
        uncertainties: [4.43],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["dearexis"],
        ratings: [16.67],
        names: ["dearexis"],
        uncertainties: [8.33],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["NoHorny"],
        ratings: [15.64],
        names: ["NoHorny"],
        uncertainties: [8.22],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["[NP]sigmal"],
        ratings: [14.52],
        names: ["[NP]sigmal"],
        uncertainties: [3.98],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Aceleo"],
        ratings: [14.50],
        names: ["Aceleo"],
        uncertainties: [8.16],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["masvor"],
        ratings: [12.79],
        names: ["Aceleo"],
        uncertainties: [7.53],
        ranks: [2]
      },
      %{
        count: 1,
        members: ["Tpioesmten"],
        ratings: [8.10],
        names: ["Tpioesmten"],
        uncertainties: [5.15],
        ranks: [2]
      }
    ]

    result = SplitNoobs.perform(expanded_group, 2) |> Map.drop([:logs])

    assert result == %{
             team_groups: %{
               1 => [
                 %{
                   count: 1,
                   group_rating: 6.784534653465353,
                   members: ["Devilsreborn"],
                   ratings: [6.784534653465353]
                 },
                 %{
                   count: 1,
                   group_rating: 1.0529900990099004,
                   members: ["NoHorny"],
                   ratings: [1.0529900990099004]
                 },
                 %{
                   count: 1,
                   group_rating: 1.4930693069306968,
                   members: ["Aceleo"],
                   ratings: [1.4930693069306968]
                 },
                 %{count: 1, group_rating: 8.1, members: ["Tpioesmten"], ratings: [8.1]},
                 %{count: 1, group_rating: 14.52, members: ["[NP]sigmal"], ratings: [14.52]}
               ],
               2 => [
                 %{
                   count: 1,
                   group_rating: 3.7399999999999975,
                   members: ["InvisibleMan"],
                   ratings: [3.7399999999999975]
                 },
                 %{
                   count: 1,
                   group_rating: 0.03300990099010417,
                   members: ["dearexis"],
                   ratings: [0.03300990099010417]
                 },
                 %{
                   count: 1,
                   group_rating: 1.20649504950495,
                   members: ["Yotap"],
                   ratings: [1.20649504950495]
                 },
                 %{
                   count: 1,
                   group_rating: 6.103742574257427,
                   members: ["masvor"],
                   ratings: [6.103742574257427]
                 },
                 %{count: 1, group_rating: 16.7, members: ["Bluto"], ratings: [16.7]}
               ]
             },
             team_players: %{
               1 => ["Devilsreborn", "NoHorny", "Aceleo", "Tpioesmten", "[NP]sigmal"],
               2 => ["InvisibleMan", "dearexis", "Yotap", "masvor", "Bluto"]
             }
           }

    ratings =
      result.team_groups
      |> Map.new(fn {k, groups} ->
        {k, BalanceLib.sum_group_rating(groups)}
      end)

    assert ratings == %{1 => 31.950594059405947, 2 => 27.78324752475248}

    deviation = BalanceLib.get_deviation(ratings)
    assert deviation == 13
  end
end
