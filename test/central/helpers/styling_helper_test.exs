defmodule Central.General.StylingHelpersTest do
  use Central.DataCase, async: true

  alias Central.Helpers.StylingHelper

  test "colours" do
    params = [
      :default,
      :primary,
      :primary2,
      :info,
      :info2,
      :success,
      :success2,
      :warning,
      :warning2,
      :danger,
      :danger2,
      :negative,
      :negative2
    ]

    for p <- params do
      {_, _, _} = StylingHelper.colours(p)
    end
  end

  test "icon" do
    params = [:report, :up, :back]

    for p <- params do
      "" <> _ = StylingHelper.icon(p)
    end
  end
end
