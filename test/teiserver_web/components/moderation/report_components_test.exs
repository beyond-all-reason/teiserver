defmodule TeiserverWeb.ModerationLive.ReportComponentsTest do
  alias TeiserverWeb.ModerationLive.ReportComponents

  use TeiserverWeb.ConnCase, async: true

  describe "ReportComponents.section_menu" do
    test "render" do
      html =
        render_component(&ReportComponents.section_menu/1, %{
          view_colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/moderation/report?search=true"
    end
  end
end
