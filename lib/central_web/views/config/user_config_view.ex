defmodule CentralWeb.Config.UserConfigView do
  use CentralWeb, :view

  def config_name(config_key) do
    config_key
    |> String.split(".")
    |> tl
  end

  def view_colour(), do: Teiserver.Config.UserConfigLib.colours()
  def icon(), do: Teiserver.Config.UserConfigLib.icon()
end
