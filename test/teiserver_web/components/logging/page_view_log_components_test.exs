defmodule TeiserverWeb.Components.Logging.PageViewLogComponentsTest do
  alias TeiserverWeb.Components.Logging.PageViewLogComponents

  use TeiserverWeb.ConnCase, async: true

  describe "PageViewLogComponents.section_menu" do
    test "render" do
      html =
        render_component(&PageViewLogComponents.section_menu/1, %{
          colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/logging/page_views"
      assert html =~ "/logging/page_views/search"
    end
  end
end
