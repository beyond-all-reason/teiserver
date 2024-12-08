defmodule Teiserver.Battle.SeasonalUncertaintyResetTaskTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use ExUnit.Case
  @moduletag :balance_test
  alias Teiserver.Battle.SeasonalUncertaintyResetTask

  test "can calculate target uncertainty" do
    result = SeasonalUncertaintyResetTask.calculate_target_uncertainty(400)
    assert result == 8.333333333333334

    one_year = 365

    one_month = one_year / 12

    # If you played yesterday then it should pick the min uncertainty of 5
    result = SeasonalUncertaintyResetTask.calculate_target_uncertainty(1)
    assert result == 5

    result = SeasonalUncertaintyResetTask.calculate_target_uncertainty(one_month)
    assert result == 5

    result = SeasonalUncertaintyResetTask.calculate_target_uncertainty(one_month * 2)
    assert result == 5.303030303030303

    result = SeasonalUncertaintyResetTask.calculate_target_uncertainty(one_month * 3)
    assert result == 5.6060606060606063

    result = SeasonalUncertaintyResetTask.calculate_target_uncertainty(one_month * 6)
    assert result == 6.515151515151516

    result = SeasonalUncertaintyResetTask.calculate_target_uncertainty(one_month * 9)
    assert result == 7.424242424242426

    result = SeasonalUncertaintyResetTask.calculate_target_uncertainty(one_month * 11)
    assert result == 8.030303030303031

    result = SeasonalUncertaintyResetTask.calculate_target_uncertainty(one_year)
    assert result == 8.333333333333334

    {_, end_date} = DateTime.new(~D[2016-05-24], ~T[13:26:08.003], "Etc/UTC")
    {_, start_date} = DateTime.new(~D[2016-04-24], ~T[13:26:08.003], "Etc/UTC")
    days = abs(DateTime.diff(start_date, end_date, :day))
    assert days == 30
  end
end
