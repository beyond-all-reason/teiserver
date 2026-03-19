defmodule TeiserverWeb.Admin.ChatView do
  use TeiserverWeb, :view

  alias Teiserver.Chat.LobbyMessageLib

  def view_colour, do: LobbyMessageLib.colours()
  def icon, do: LobbyMessageLib.icon()
end
