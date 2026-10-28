defmodule TeiserverWeb.Components.Admin.MatchComponentsTest do
  alias Teiserver.AccountFixtures
  alias TeiserverWeb.Components.Admin.MatchComponents

  use TeiserverWeb.ConnCase, async: true

  describe "MatchComponents.section_menu" do
    test "render" do
      user = AccountFixtures.user_fixture()

      html =
        render_component(&MatchComponents.section_menu/1, %{
          current_user: user,
          colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/teiserver/admin/matches?search=true"
    end
  end
end
