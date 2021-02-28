defmodule Central.Helpers.DatePresetTest do
  use Central.DataCase, async: true
  alias Central.Helpers.DatePresets

  test "test basic presets" do
    DatePresets.presets()
    |> Enum.map(fn p ->
      DatePresets.parse(p, "", "")
    end)
  end

  test "test long presets" do
    DatePresets.long_presets()
    |> Enum.map(fn p ->
      DatePresets.parse(p, "", "")
    end)
  end

  test "test short ranges" do
    DatePresets.short_ranges()
    |> Enum.map(fn p ->
      DatePresets.parse(p, "", "")
    end)
  end

  test "test long ranges" do
    DatePresets.long_ranges()
    |> Enum.map(fn p ->
      DatePresets.parse(p, "", "")
    end)
  end

  test "test past dates" do
    DatePresets.past_dates()
    |> Enum.map(fn p ->
      DatePresets.parse(p)
    end)
  end

  test "test future dates" do
    DatePresets.future_dates()
    |> Enum.map(fn p ->
      DatePresets.parse(p)
    end)
  end
end
