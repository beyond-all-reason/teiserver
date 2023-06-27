defmodule TeiserverWeb.Communication.NotificationView do
  use CentralWeb, :view

  def view_colour(), do: Teiserver.Communication.NotificationLib.colours()
  def icon(), do: Teiserver.Communication.NotificationLib.icon()
end
