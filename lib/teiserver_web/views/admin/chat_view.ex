defmodule TeiserverWeb.Admin.ChatView do
  alias Teiserver.Chat.LobbyMessageLib

  use TeiserverWeb, :view

  def view_colour, do: LobbyMessageLib.colours()
  def icon, do: LobbyMessageLib.icon()
end
