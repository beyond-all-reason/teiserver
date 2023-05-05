defmodule TeiserverWeb.Admin.ChatView do
  use TeiserverWeb, :view

  def view_colour, do: Teiserver.Chat.LobbyMessageLib.colours()
  def icon, do: Teiserver.Chat.LobbyMessageLib.icon()
end
