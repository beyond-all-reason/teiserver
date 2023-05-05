defmodule CentralWeb.Communication.GeneralView do
  use CentralWeb, :view

  def icon(), do: Central.Communication.NotificationLib.icon()
  def view_colour(), do: Central.Communication.NotificationLib.colours()
end
