defmodule TeiserverWeb.Components.Moderation.BanComponentsTest do
  alias TeiserverWeb.Components.Moderation.BanComponents

  use TeiserverWeb.ConnCase, async: true

  describe "BanComponents.section_menu" do
    test "render" do
      html =
        render_component(&BanComponents.section_menu/1, %{
          colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/moderation/ban"
    end
  end
end
