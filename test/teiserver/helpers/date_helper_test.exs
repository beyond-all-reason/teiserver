defmodule Teiserver.Helpers.DateHelperTest do
  alias Teiserver.Helper.DateHelper
  use Teiserver.DataCase, async: true

  describe "beginning_of_quarter/1" do
    test "Q1" do
      assert DateHelper.beginning_of_quarter(~D[2026-02-15]) == ~D[2026-01-01]
      assert DateHelper.beginning_of_quarter(~D[2026-03-31]) == ~D[2026-01-01]
    end

    test "Q2" do
      assert DateHelper.beginning_of_quarter(~D[2026-04-10]) == ~D[2026-04-01]
      assert DateHelper.beginning_of_quarter(~D[2026-06-30]) == ~D[2026-04-01]
    end

    test "Q3" do
      assert DateHelper.beginning_of_quarter(~D[2026-07-01]) == ~D[2026-07-01]
      assert DateHelper.beginning_of_quarter(~D[2026-09-15]) == ~D[2026-07-01]
    end

    test "Q4" do
      assert DateHelper.beginning_of_quarter(~D[2026-10-05]) == ~D[2026-10-01]
      assert DateHelper.beginning_of_quarter(~D[2026-12-31]) == ~D[2026-10-01]
    end
  end

  describe "end_of_quarter/1" do
    test "Q1" do
      assert DateHelper.end_of_quarter(~D[2026-01-15]) == ~D[2026-03-31]
    end

    test "Q2" do
      assert DateHelper.end_of_quarter(~D[2026-05-10]) == ~D[2026-06-30]
    end

    test "Q3" do
      assert DateHelper.end_of_quarter(~D[2026-08-20]) == ~D[2026-09-30]
    end

    test "Q4" do
      assert DateHelper.end_of_quarter(~D[2026-11-01]) == ~D[2026-12-31]
    end
  end

  describe "quarter/1" do
    test "returns correct quarter for each month" do
      for {month, expected_q} <- [
            {1, 1},
            {2, 1},
            {3, 1},
            {4, 2},
            {5, 2},
            {6, 2},
            {7, 3},
            {8, 3},
            {9, 3},
            {10, 4},
            {11, 4},
            {12, 4}
          ] do
        date = Date.new!(2026, month, 1)
        assert DateHelper.quarter(date) == expected_q, "month #{month} should be Q#{expected_q}"
      end
    end
  end

  describe "beginning_of_month/1" do
    test "returns first day of month" do
      assert DateHelper.beginning_of_month(~D[2026-05-19]) == ~D[2026-05-01]
    end
  end

  describe "beginning_of_year/1" do
    test "returns Jan 1st" do
      assert DateHelper.beginning_of_year(~D[2026-07-15]) == ~D[2026-01-01]
    end
  end

  describe "end_of_year/1" do
    test "returns Dec 31st" do
      assert DateHelper.end_of_year(~D[2026-03-10]) == ~D[2026-12-31]
    end
  end

  describe "beginning_of_day/1" do
    test "zeroes time components" do
      dt = DateTime.new!(~D[2026-05-19], ~T[14:30:45.123456], "Etc/UTC")
      result = DateHelper.beginning_of_day(dt)
      assert result.hour == 0
      assert result.minute == 0
      assert result.second == 0
      assert result.microsecond == {0, 0}
      assert DateTime.to_date(result) == ~D[2026-05-19]
    end
  end

  describe "iso_week/1" do
    test "returns {year, week_number}" do
      {year, week} = DateHelper.iso_week(~D[2026-01-05])
      assert is_integer(year)
      assert is_integer(week)
      assert week >= 1 and week <= 53
    end

    test "leap year date thats falls in week 1 of following year" do
      # Dec 30 is Monday → ISO week 1 of 2025, not week 52/53 of 2024
      assert DateHelper.iso_week(~D[2024-12-30]) == {2025, 1}
    end

    test "leap year date after Feb 28 where wrong logic gives week-1" do
      # 2024 is a leap year; Mar 11 is a Monday → ISO week 11
      # wrong leap-year logic (treating Feb as 28 days) shifts day-of-week by 1,
      # making Mar 11 appear as Sunday → week 10 instead of 11
      assert DateHelper.iso_week(~D[2024-03-11]) == {2024, 11}
    end
  end

  describe "to_datetime/1" do
    test "converts Date to DateTime at midnight UTC" do
      result = DateHelper.to_datetime(~D[2026-05-19])
      assert result == ~U[2026-05-19 00:00:00Z]
    end
  end

  describe "parse_dmy/1" do
    test "parses DD/MM/YYYY format" do
      assert DateHelper.parse_dmy("19/05/2026") == ~D[2026-05-19]
    end

    test "returns nil for nil" do
      assert DateHelper.parse_dmy(nil) == nil
    end

    test "returns nil for empty string" do
      assert DateHelper.parse_dmy("") == nil
    end

    test "raises for invalid date" do
      assert_raise ArgumentError, fn -> DateHelper.parse_dmy("40/05/2026") end
    end

    test "raises for non-date string" do
      assert_raise ArgumentError, fn -> DateHelper.parse_dmy("not/a/date") end
    end
  end

  describe "parse_ymd/1" do
    test "parses YYYY-MM-DD format" do
      assert DateHelper.parse_ymd("2026-05-19") == ~D[2026-05-19]
    end

    test "returns nil for nil" do
      assert DateHelper.parse_ymd(nil) == nil
    end

    test "returns nil for empty string" do
      assert DateHelper.parse_ymd("") == nil
    end

    test "raises for invalid date" do
      assert_raise ArgumentError, fn -> DateHelper.parse_ymd("2026-05-40") end
    end

    test "raises for non-date string" do
      assert_raise ArgumentError, fn -> DateHelper.parse_ymd("not-a-date") end
    end
  end

  describe "parse_ymd_hms/1" do
    test "parses YYYY-MM-DD HH:MM:SS format" do
      assert DateHelper.parse_ymd_hms("2026-05-19 14:30:45") == ~N[2026-05-19 14:30:45]
    end

    test "returns nil for nil" do
      assert DateHelper.parse_ymd_hms(nil) == nil
    end

    test "returns nil for empty string" do
      assert DateHelper.parse_ymd_hms("") == nil
    end

    test "raises for non-datetime string" do
      assert_raise ArgumentError, fn -> DateHelper.parse_ymd_hms("not-a-date 12:30:45") end
    end

    test "raises for invalid date" do
      assert_raise ArgumentError, fn -> DateHelper.parse_ymd_hms("2026-05-35 14:12:45") end
    end

    test "raises for invalid time" do
      assert_raise ArgumentError, fn -> DateHelper.parse_ymd_hms("2026-05-20 24:62:99") end
    end

    test "raises for invalid date and time" do
      assert_raise ArgumentError, fn -> DateHelper.parse_ymd_hms("2026-05-50 26:12:40") end
    end
  end

  describe "parse_time_input/1" do
    test "routes to ymd_hms when colon present" do
      assert DateHelper.parse_time_input("2026-05-19 14:30:45") == ~N[2026-05-19 14:30:45]
    end

    test "routes to ymd when dash present" do
      assert DateHelper.parse_time_input("2026-05-19") == ~D[2026-05-19]
    end

    test "routes to dmy otherwise" do
      assert DateHelper.parse_time_input("19/05/2026") == ~D[2026-05-19]
    end
  end

  describe "duration_to_str/1" do
    test "returns seconds for values under 1 hour" do
      assert DateHelper.duration_to_str(45) == "45 seconds"
    end

    test "returns '1 hour' for exactly one hour" do
      assert DateHelper.duration_to_str(3_600) == "1 hour"
    end

    test "returns plural hours for multiple hours" do
      assert DateHelper.duration_to_str(7_200) == "2 hours"
    end

    test "returns '1 day' for exactly one day" do
      assert DateHelper.duration_to_str(86_400) == "1 day"
    end

    test "returns plural days for multiple days" do
      assert DateHelper.duration_to_str(172_800) == "2 days"
    end
  end

  describe "duration_to_str_short/1" do
    test "returns nil for nil" do
      assert DateHelper.duration_to_str_short(nil) == nil
    end

    test "only seconds" do
      assert DateHelper.duration_to_str_short(45) == "00:45"
    end

    test "minutes and seconds" do
      assert DateHelper.duration_to_str_short(125) == "02:05"
    end

    test "hours, minutes and seconds" do
      assert DateHelper.duration_to_str_short(3_661) == "1:01:01"
    end

    test "days, hours, minutes and seconds" do
      assert DateHelper.duration_to_str_short(90_061) == "1d 1:01:01"
    end
  end

  describe "greater_than/2" do
    test "with DateTimes" do
      a = ~U[2026-05-19 10:00:00Z]
      b = ~U[2026-05-19 09:00:00Z]
      assert DateHelper.greater_than(a, b) == true
      assert DateHelper.greater_than(b, a) == false
      assert DateHelper.greater_than(a, a) == false
    end

    test "with Dates" do
      assert DateHelper.greater_than(~D[2026-05-20], ~D[2026-05-19]) == true
      assert DateHelper.greater_than(~D[2026-05-19], ~D[2026-05-20]) == false
    end

    test "with nil" do
      assert DateHelper.greater_than(nil, ~U[2026-05-19 00:00:00Z]) == false
      assert DateHelper.greater_than(~U[2026-05-19 00:00:00Z], nil) == true
    end
  end

  describe "less_than/2" do
    test "with DateTimes" do
      a = ~U[2026-05-19 09:00:00Z]
      b = ~U[2026-05-19 10:00:00Z]
      assert DateHelper.less_than(a, b) == true
      assert DateHelper.less_than(b, a) == false
      assert DateHelper.less_than(a, a) == false
    end

    test "with Dates" do
      assert DateHelper.less_than(~D[2026-05-19], ~D[2026-05-20]) == true
      assert DateHelper.less_than(~D[2026-05-20], ~D[2026-05-19]) == false
    end

    test "with nil" do
      assert DateHelper.less_than(nil, ~U[2026-05-19 00:00:00Z]) == true
      assert DateHelper.less_than(~U[2026-05-19 00:00:00Z], nil) == false
    end
  end
end
