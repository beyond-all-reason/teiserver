defmodule TeiserverWeb.Admin.SiteConfigView do
  use TeiserverWeb, :view

  def config_name(config_key) do
    config_key
    |> String.split(".")
    |> tl()
  end

  @spec view_colour :: atom()
  def view_colour(), do: Teiserver.Config.SiteConfigLib.colours()

  @spec icon :: String.t()
  def icon(), do: Teiserver.Config.SiteConfigLib.icon()
end
