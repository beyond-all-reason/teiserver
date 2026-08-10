defmodule TeiserverWeb.Components.Admin.CodeComponentsTest do
  alias TeiserverWeb.Components.Admin.CodeComponents

  use TeiserverWeb.ConnCase, async: true

  describe "CodeComponents.section_menu" do
    test "render" do
      html =
        render_component(&CodeComponents.section_menu/1, %{
          colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/teiserver/admin/codes"
      assert html =~ "/teiserver/admin/codes/new"
    end
  end
end
