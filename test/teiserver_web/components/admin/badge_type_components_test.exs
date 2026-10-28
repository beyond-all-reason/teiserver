defmodule TeiserverWeb.Components.Admin.BadgeTypeComponentsTest do
  alias TeiserverWeb.Components.Admin.BadgeTypeComponents

  use TeiserverWeb.ConnCase, async: true

  describe "BadgeTypeComponents.section_menu" do
    test "render" do
      html =
        render_component(&BadgeTypeComponents.section_menu/1, %{
          colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/teiserver/admin/badge_types"
      assert html =~ "/teiserver/admin/badge_types/new"
    end
  end
end
