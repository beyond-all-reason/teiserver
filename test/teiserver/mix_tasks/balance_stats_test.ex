defmodule Mix.Tasks.Teiserver.BalanceStatsTests do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use ExUnit.Case
  @moduletag :balance_test
  alias Mix.Tasks.Teiserver.BalanceStats

  test "Adjusted rating calculation" do
    team_players = %{1 => [31, 15, 40, 1, 39, 12, 28, 3], 2 => [17, 10, 33, 19, 23, 35, 36, 18]}
    rating_logs = get_large_team_rating_logs()
    rating = BalanceStats.adjusted_rating(31, rating_logs)
    assert rating == 0.7676847201440002

    # Calculate team adjusted rating
    rating = BalanceStats.calculate_rating_diff(team_players, rating_logs)

    assert rating == %{
             adjusted_team_rating_diff: 2.047099982927838,
             team_rating_diff: 3.1937394354587525
           }
  end

  defp get_large_team_rating_logs() do
    %{
      1 => %Teiserver.Game.RatingLog{
        id: 317,
        user_id: 1,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 21.990324316979112,
          "rating_value_change" => 0.8536998038911463,
          "skill" => 30.02382729538406,
          "skill_change" => 0.820207243963992,
          "uncertainty" => 8.033502978404949,
          "uncertainty_change" => -0.03349255992715072
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      3 => %Teiserver.Game.RatingLog{
        id: 325,
        user_id: 3,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 12.945810679569687,
          "rating_value_change" => -0.7955581015208075,
          "skill" => 21.02629801073986,
          "skill_change" => -0.8299582827594669,
          "uncertainty" => 8.080487331170174,
          "uncertainty_change" => -0.0344001812386594
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      10 => %Teiserver.Game.RatingLog{
        id: 312,
        user_id: 10,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 17.050760205536292,
          "rating_value_change" => 0.8489687243580626,
          "skill" => 25.062959178945828,
          "skill_change" => 0.8158188187110724,
          "uncertainty" => 8.012198973409534,
          "uncertainty_change" => -0.03314990564699194
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      12 => %Teiserver.Game.RatingLog{
        id: 323,
        user_id: 12,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 16.900594909902587,
          "rating_value_change" => -0.7805077795744424,
          "skill" => 24.90198790222699,
          "skill_change" => -0.8136261620124223,
          "uncertainty" => 8.001392992324403,
          "uncertainty_change" => -0.033118382437978156
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      15 => %Teiserver.Game.RatingLog{
        id: 316,
        user_id: 15,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 20.7465750071461,
          "rating_value_change" => 0.846617497382887,
          "skill" => 28.748163241128765,
          "skill_change" => 0.8136376310906428,
          "uncertainty" => 8.001588233982666,
          "uncertainty_change" => -0.03297986629224248
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      17 => %Teiserver.Game.RatingLog{
        id: 320,
        user_id: 17,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 13.681950729816448,
          "rating_value_change" => -0.8026254930596437,
          "skill" => 21.799320756738933,
          "skill_change" => -0.8376313757099076,
          "uncertainty" => 8.117370026922485,
          "uncertainty_change" => -0.03500588265026394
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      18 => %Teiserver.Game.RatingLog{
        id: 321,
        user_id: 18,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 16.254407653196623,
          "rating_value_change" => -0.8040877490904776,
          "skill" => 24.379388443189605,
          "skill_change" => -0.8392192548275048,
          "uncertainty" => 8.124980789992984,
          "uncertainty_change" => -0.03513150573702717
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      19 => %Teiserver.Game.RatingLog{
        id: 311,
        user_id: 19,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 19.911872074252834,
          "rating_value_change" => 0.8548696146779271,
          "skill" => 27.950633132007184,
          "skill_change" => 0.82129222569462,
          "uncertainty" => 8.038761057754348,
          "uncertainty_change" => -0.033577388983308865
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      23 => %Teiserver.Game.RatingLog{
        id: 318,
        user_id: 23,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 18.914815307810343,
          "rating_value_change" => 0.8802705944743963,
          "skill" => 27.066829793305708,
          "skill_change" => 0.8448410940152868,
          "uncertainty" => 8.152014485495366,
          "uncertainty_change" => -0.03542950045910764
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      28 => %Teiserver.Game.RatingLog{
        id: 314,
        user_id: 28,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 16.55046981481037,
          "rating_value_change" => 0.8834210584337523,
          "skill" => 24.716410534718168,
          "skill_change" => 0.8477604913614805,
          "uncertainty" => 8.1659407199078,
          "uncertainty_change" => -0.035660567072270055
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      31 => %Teiserver.Game.RatingLog{
        id: 324,
        user_id: 31,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 16.920187736488288,
          "rating_value_change" => -0.8296565654251218,
          "skill" => 25.17714666434607,
          "skill_change" => -0.8670014554023133,
          "uncertainty" => 8.256958927857779,
          "uncertainty_change" => -0.03734488997719332
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      33 => %Teiserver.Game.RatingLog{
        id: 326,
        user_id: 33,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 15.996383809875415,
          "rating_value_change" => -0.8188213615518407,
          "skill" => 24.197666944229535,
          "skill_change" => -0.8552244238000739,
          "uncertainty" => 8.20128313435412,
          "uncertainty_change" => -0.0364030622482332
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      35 => %Teiserver.Game.RatingLog{
        id: 319,
        user_id: 35,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 18.078967552248244,
          "rating_value_change" => -0.8172880435191772,
          "skill" => 26.272342158954853,
          "skill_change" => -0.8535582849747918,
          "uncertainty" => 8.193374606706609,
          "uncertainty_change" => -0.036270241455616414
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      36 => %Teiserver.Game.RatingLog{
        id: 315,
        user_id: 36,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 17.57967901065515,
          "rating_value_change" => 0.9130123439884841,
          "skill" => 25.875166955461587,
          "skill_change" => 0.8751669554615873,
          "uncertainty" => 8.295487944806439,
          "uncertainty_change" => -0.03784538852689501
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      39 => %Teiserver.Game.RatingLog{
        id: 313,
        user_id: 39,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 18.65403724626335,
          "rating_value_change" => 0.9041929443499406,
          "skill" => 26.911149575150695,
          "skill_change" => 0.8670014554023133,
          "uncertainty" => 8.257112328887345,
          "uncertainty_change" => -0.03719148894762725
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      },
      40 => %Teiserver.Game.RatingLog{
        id: 322,
        user_id: 40,
        rating_type_id: 4,
        match_id: 38,
        party_id: nil,
        value: %{
          "rating_value" => 15.954576067690587,
          "rating_value_change" => -0.8198493989404927,
          "skill" => 24.161157450788576,
          "skill_change" => -0.8563415768276279,
          "uncertainty" => 8.206581383097989,
          "uncertainty_change" => -0.03649217788713521
        },
        inserted_at: ~U[2024-09-03 00:50:00Z]
      }
    }
  end
end
