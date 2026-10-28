defmodule TeiserverWeb.Admin.ChatView do
  alias Teiserver.Chat.SpringLobbyMessageLib

  use TeiserverWeb, :view

  def view_colour, do: SpringLobbyMessageLib.colours()
  def icon, do: SpringLobbyMessageLib.icon()
end
