defmodule CentralWeb.Communication.GeneralView do
  use CentralWeb, :view

  def icon(), do: Central.Communication.NotificationLib.icon()
  def view_colour(), do: Central.Communication.NotificationLib.colours()

  def view_colour("posts"), do: Central.Communication.PostLib.colours()
  def view_colour("categories"), do: Central.Communication.CategoryLib.colours()
  def view_colour("comments"), do: Central.Communication.CommentLib.colours()
  def view_colour("files"), do: Central.Communication.BlogFileLib.colours()
end
