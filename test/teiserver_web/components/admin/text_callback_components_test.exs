defmodule TeiserverWeb.Components.Admin.TextCallbackComponentsTest do
  alias TeiserverWeb.Components.Admin.TextCallbackComponents

  use TeiserverWeb.ConnCase, async: true

  describe "TextCallbackComponents.section_menu" do
    test "render" do
      html =
        render_component(&TextCallbackComponents.section_menu/1, %{
          colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/admin/text_callbacks"
      assert html =~ "/admin/text_callbacks/new"
    end
  end
end
