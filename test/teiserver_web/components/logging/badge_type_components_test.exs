defmodule TeiserverWeb.Components.Logging.MatchLogComponentsTest do
  alias TeiserverWeb.Components.Logging.MatchLogComponents

  use TeiserverWeb.ConnCase, async: true

  describe "MatchLogComponents.section_menu" do
    test "render" do
      html =
        render_component(&MatchLogComponents.section_menu/1, %{
          colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/logging/match/day_metrics"
      assert html =~ "/logging/match/export_form"
    end
  end
end
