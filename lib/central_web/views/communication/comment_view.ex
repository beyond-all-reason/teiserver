defmodule CentralWeb.Communication.CommentView do
  use CentralWeb, :view

  def view_colour(), do: Central.Communication.CommentLib.colours()
  def icon(), do: Central.Communication.CommentLib.icon()
end
