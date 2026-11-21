defmodule TeiserverWeb.LiveComponents.CommandPaletteTest do
  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib
  alias TeiserverWeb.LiveComponents.CommandPalette

  use TeiserverWeb.ConnCase, async: true

  describe "TeiserverWeb.LiveComponents.CommandPalette" do
    test "render without form" do
      user = AccountFixtures.user_fixture(%{roles: ["Admin"]})
      scope = GeneralTestLib.scope_fixture(user)

      html =
        render_component(CommandPalette, %{
          scope: scope
        })

      # Assert we have the hidden element and we don't have an error
      # raised rendering it in general
      assert html =~ ~s(<div id="command-palette" phx-hook="CommandPalette">)
    end
  end
end
