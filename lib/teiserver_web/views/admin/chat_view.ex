defmodule TeiserverWeb.Admin.ChatView do
  use TeiserverWeb, :view

  def colours, do: Central.Communication.CommentLib.colours()
  def icon, do: Central.Communication.CommentLib.icon()
end
