defmodule TeiserverWeb.Components.Moderation.ActionComponentsTest do
  alias TeiserverWeb.Components.Moderation.ActionComponents

  use TeiserverWeb.ConnCase, async: true

  describe "ActionComponents.section_menu" do
    test "render" do
      html =
        render_component(&ActionComponents.section_menu/1, %{
          colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/moderation/action"
      assert html =~ "/moderation/action/search"
    end
  end
end
