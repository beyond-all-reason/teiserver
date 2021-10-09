defmodule CentralWeb.Admin.SiteConfigView do
  use CentralWeb, :view

  def config_name(config_key) do
    config_key
    |> String.split(".")
    |> tl
  end

  def colours(), do: Central.Config.SiteConfigLib.colours()
  def icon(), do: Central.Config.SiteConfigLib.icon()
end
