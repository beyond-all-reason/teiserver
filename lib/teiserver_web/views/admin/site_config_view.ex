defmodule BarserverWeb.Admin.SiteConfigView do
  use BarserverWeb, :view

  def config_name(config_key) do
    config_key
    |> String.split(".")
    |> tl
  end

  @spec view_colour :: atom()
  def view_colour(), do: Barserver.Config.SiteConfigLib.colours()

  @spec icon :: String.t()
  def icon(), do: Barserver.Config.SiteConfigLib.icon()
end
