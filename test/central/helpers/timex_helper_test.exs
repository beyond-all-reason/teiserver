defmodule Central.Helpers.TimexHelperTest do
  use Central.DataCase, async: true

  alias Central.Helpers.TimexHelper

  @from Timex.to_datetime({{2013, 12, 4}, {06, 20, 5}}, "Europe/London")
  @today Timex.beginning_of_day(@from)

  test "date_to_str" do
    values = [
      {nil, :day_name, ""},
      {@from, :day_name, "Wednesday"},
      {@from, :dmy, "04/12/2013"},
      {@from, :ymd, "2013-12-04"},
      {@from, :hms_dmy, "06:20:05 04/12/2013"},
      {@from, :hms_or_dmy, "Today at 06:20:05"},
      {@from, :hms_or_hmsdmy, "Today at 06:20:05"},
      {@today, :hms_or_hmsdmy, "Today at 00:00:00"},
      {Timex.shift(@from, days: -1), :hms_or_dmy, "03/12/2013"},
      {@from, :hm_dmy, "06:20 04/12/2013"},
      {@from, :ymd_hms, "2013-12-04 06:20:05"},
      {@from, :hms, "06:20:05"},
      {@from, :clock24, "0620"},
      {@from, :html_input, "2013-12-04T06:20"},
      {Timex.shift(@from, hours: -1), :hms_or_dmy, "Today at 05:20:05"},
      {Timex.shift(@from, days: -14), :hms_or_dmy, "20/11/2013"},
      {Timex.shift(@from, days: 2), :hms_or_dmy, "06/12/2013"},
      {Timex.shift(@from, hours: -1), :hm_or_dmy, "Today at 05:20"},
      {Timex.shift(@from, days: -14), :hm_or_dmy, "20/11/2013"},
      {Timex.shift(@from, days: 2), :hm_or_dmy, "06/12/2013"},
      {@from, :everything, "2013-12-04 06:20:05, Wednesday"}
    ]

    for {input_value, format, expected} <- values do
      assert TimexHelper.date_to_str(input_value, format: format, now: @today) == expected
    end

    # Now test it runs with just a "now" argument
    assert TimexHelper.date_to_str(@today) == "04/12/2013"
  end

  test "date_to_str until" do
    assert TimexHelper.date_to_str(@from, format: :hms_dmy, now: @today, until: true) ==
             "06:20:05 04/12/2013, in 6 hours"

    assert TimexHelper.date_to_str(@from, format: :hms_dmy, now: @today, until: "until-span-id") ==
             "06:20:05 04/12/2013<span id='until-span-id'>, in 6 hours</span>"
  end

  test "time_until" do
    assert TimexHelper.time_until(Timex.shift(Timex.now(), hours: 12)) == "12 hours"
    assert TimexHelper.time_until(Timex.shift(Timex.now(), hours: 40)) == "1 day, 16 hours"
    assert TimexHelper.time_until(Timex.now()) == ""
    assert TimexHelper.time_until(Timex.shift(Timex.now(), hours: -12)) == "12 hours"
    assert TimexHelper.time_until(Timex.shift(Timex.now(), hours: -40)) == "1 day, 16 hours"
  end

  test "parse dmy" do
    values = [
      {nil, nil},
      {"", nil},
      {"04/12/2013", ~N[2013-12-04 00:00:00]},
      {"11/09/2013", ~N[2013-09-11 00:00:00]}
    ]

    for {input_value, expected} <- values do
      assert TimexHelper.parse_dmy(input_value) == expected
    end
  end

  test "duration_to_str" do
    assert TimexHelper.duration_to_str(50) == "50 seconds"
    assert TimexHelper.duration_to_str(180) == "180 seconds"
    assert TimexHelper.duration_to_str(3680) == "1 hour"
  end

  test "duration_to_str_short" do
    assert TimexHelper.duration_to_str_short(50) == "00:50"
    assert TimexHelper.duration_to_str_short(180) == "03:00"
    assert TimexHelper.duration_to_str_short(2339) == "38:59"
    assert TimexHelper.duration_to_str_short(3680) == "1:01:20"
  end
end
