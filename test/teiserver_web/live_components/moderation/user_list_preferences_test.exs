defmodule TeiserverWeb.LiveComponents.Moderation.UserListPreferencesTest do
  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib
  alias TeiserverWeb.LiveComponents.Moderation.UserListPreferences

  use TeiserverWeb.ConnCase, async: true

  describe "TeiserverWeb.LiveComponents.Moderation.UserListPreferences" do
    test "render" do
      user = AccountFixtures.user_fixture()
      scope = GeneralTestLib.scope_fixture(user)

      html =
        render_component(UserListPreferences, %{
          id: "user-list-preferences-form",
          preferences: %{},
          scope: scope
        })

      html = String.replace(html, ~r/\s+/, " ")

      # At this stage we are focusing on ensuring it renders
      assert html =~
               ~s(<span class="btn btn-secondary px-2 btn-soft" phx-click="toggle-form" phx-target="-1">)
    end
  end
end
