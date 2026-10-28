defmodule TeiserverWeb.Components.Logging.ServerViewLogComponentsTest do
  alias TeiserverWeb.Components.Logging.ServerViewLogComponents

  use TeiserverWeb.ConnCase, async: true

  describe "ServerViewLogComponents.section_menu" do
    test "render" do
      html =
        render_component(&ServerViewLogComponents.section_menu/1, %{
          colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/logging/server/day"
      assert html =~ "/logging/server/show/day/today"
      assert html =~ "/logging/server/show/quarter/today"
    end
  end
end
