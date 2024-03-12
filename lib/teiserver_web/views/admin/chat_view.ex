defmodule BarserverWeb.Admin.ChatView do
  use BarserverWeb, :view

  def view_colour, do: Barserver.Chat.LobbyMessageLib.colours()
  def icon, do: Barserver.Chat.LobbyMessageLib.icon()
end
