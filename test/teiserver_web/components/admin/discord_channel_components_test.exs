defmodule TeiserverWeb.Components.Admin.DiscordChannelComponentsTest do
  alias TeiserverWeb.Components.Admin.DiscordChannelComponents

  use TeiserverWeb.ConnCase, async: true

  describe "DiscordChannelComponents.section_menu" do
    test "render" do
      html =
        render_component(&DiscordChannelComponents.section_menu/1, %{
          colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/admin/discord_channels"
      assert html =~ "/admin/discord_channels/new"
    end
  end
end
