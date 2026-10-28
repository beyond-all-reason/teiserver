defmodule TeiserverWeb.Components.Logging.AggregateViewLogComponentsTest do
  alias TeiserverWeb.Components.Logging.AggregateViewLogComponents

  use TeiserverWeb.ConnCase, async: true

  describe "AggregateViewLogComponents.section_menu" do
    test "render" do
      html =
        render_component(&AggregateViewLogComponents.section_menu/1, %{
          colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/logging/aggregate_views"
      assert html =~ "/logging/aggregate_views/perform"
    end
  end
end
