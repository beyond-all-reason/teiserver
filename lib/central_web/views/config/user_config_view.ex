defmodule CentralWeb.Config.UserConfigView do
  use CentralWeb, :view

  def config_name(config_key) do
    config_key
    |> String.split(".")
    |> tl
  end

  def view_colour(), do: Central.Config.UserConfigLib.colours()
  def icon(), do: Central.Config.UserConfigLib.icon()
end
