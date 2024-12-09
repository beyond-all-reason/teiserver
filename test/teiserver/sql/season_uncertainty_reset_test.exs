defmodule Teiserver.Sql.SeasonUncertaintyResetTest do
  @moduledoc false
  use Teiserver.DataCase

  test "it can calculate seasonal uncertainty reset target" do
    # Start by removing all anon properties
    {:ok, now} = DateTime.now("Etc/UTC")

    result = calculate_seasonal_uncertainty(now)
    assert result == 5

    # Now 30 days ago
    month = 365 / 12
    last_updated = DateTime.add(now, -month |> trunc(), :day)
    result = calculate_seasonal_uncertainty(last_updated)

    # assert_in_delta checks that the result is close to expected. Helps deal with rounding issues
    assert_in_delta(result, 5, 0.1)

    # Now 2 months ago
    last_updated = DateTime.add(now, (-2 * month) |> trunc(), :day)
    result = calculate_seasonal_uncertainty(last_updated)
    assert_in_delta(result, 5.294728102947281, 0.1)

    # Now 3 months ago
    last_updated = DateTime.add(now, (-3 * month) |> trunc(), :day)
    result = calculate_seasonal_uncertainty(last_updated)
    assert_in_delta(result, 5.6035699460357, 0.1)

    # Now 6 months ago
    last_updated = DateTime.add(now, (-6 * month) |> trunc(), :day)
    result = calculate_seasonal_uncertainty(last_updated)
    assert_in_delta(result, 6.510170195101702, 0.1)

    # Now 9 months ago
    last_updated = DateTime.add(now, (-9 * month) |> trunc(), :day)
    result = calculate_seasonal_uncertainty(last_updated)
    assert_in_delta(result, 7.416770444167705, 0.1)

    # Now 11 months ago
    last_updated = DateTime.add(now, (-11 * month) |> trunc(), :day)
    result = calculate_seasonal_uncertainty(last_updated)
    assert_in_delta(result, 8.024491490244916, 0.1)

    # Now 12 months ago
    last_updated = DateTime.add(now, (-12 * month) |> trunc(), :day)
    result = calculate_seasonal_uncertainty(last_updated)
    assert_in_delta(result, 8.333333333333334, 0.1)

    # Now 13 months ago
    last_updated = DateTime.add(now, (-13 * month) |> trunc(), :day)

    result = calculate_seasonal_uncertainty(last_updated)
    assert_in_delta(result, 8.333333333333334, 0.1)
  end

  # This will calculate the new uncertainty during a season reset
  # The longer your last_updated is from today, the more your uncertainty will be reset
  # The number should range from min_uncertainty and default_uncertainty (8.333)
  # Your new_uncertainty can grow from current_uncertainty but never reduce
  # Full details in comments of the sql function calculate_season_uncertainty
  defp calculate_seasonal_uncertainty(last_updated) do
    current_uncertainty = 1
    min_uncertainty = 5
    query = "SELECT calculate_season_uncertainty($1, $2, $3);"

    results =
      Ecto.Adapters.SQL.query!(Repo, query, [current_uncertainty, last_updated, min_uncertainty])

    [new_uncertainty] =
      results.rows
      |> Enum.at(0)

    new_uncertainty
  end
end
