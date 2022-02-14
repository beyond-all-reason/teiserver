defmodule TeiserverWeb.Admin.ChatView do
  use TeiserverWeb, :view

  def view_colour, do: Central.Communication.CommentLib.colours()
  def icon, do: Central.Communication.CommentLib.icon()
end
