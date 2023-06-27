defmodule TeiserverWeb.Communication.GeneralView do
  use CentralWeb, :view

  def icon(), do: Teiserver.Communication.NotificationLib.icon()
  def view_colour(), do: Teiserver.Communication.NotificationLib.colours()
end
