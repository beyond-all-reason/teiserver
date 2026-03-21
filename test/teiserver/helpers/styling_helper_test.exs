defmodule Teiserver.General.StylingHelpersTest do
  alias Teiserver.Helper.StylingHelper

  use Teiserver.DataCase, async: true

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
      :danger2
    ]

    for p <- params do
      {_bg, _fg, _border} = StylingHelper.colours(p)
    end
  end

  test "icon" do
    params = [:report, :up, :back]

    for p <- params do
      "" <> _icon = StylingHelper.icon(p)
    end
  end
end
