defmodule TeiserverWeb.Admin.SiteConfigView do
  use TeiserverWeb, :view

  alias Teiserver.Config.SiteConfigLib

  def config_name(config_key) do
    config_key
    |> String.split(".")
    |> tl()
  end

  @spec view_colour :: atom()
  def view_colour(), do: SiteConfigLib.colours()

  @spec icon :: String.t()
  def icon(), do: SiteConfigLib.icon()
end
