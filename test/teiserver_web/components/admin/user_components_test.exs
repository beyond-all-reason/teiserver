defmodule TeiserverWeb.Components.Admin.UserComponentsTest do
  alias Teiserver.AccountFixtures
  alias TeiserverWeb.Components.Admin.UserComponents

  use TeiserverWeb.ConnCase, async: true

  describe "UserComponents.section_menu" do
    test "render" do
      user = AccountFixtures.user_fixture(%{roles: ["admin"]})

      html =
        render_component(&UserComponents.section_menu/1, %{
          colour: "neutral",
          active: "index",
          current_user: user
        })

      # The links we expect to see
      assert html =~ "/teiserver/admin/user"
      assert html =~ "/teiserver/admin/client"
      assert html =~ "/teiserver/admin/users/data_search"
    end
  end
end
