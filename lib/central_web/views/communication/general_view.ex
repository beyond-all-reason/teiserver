defmodule CentralWeb.Communication.GeneralView do
  use CentralWeb, :view

  def icon(), do: Central.Communication.NotificationLib.icon()
  def colours(), do: Central.Communication.NotificationLib.colours()

  def colours("posts"), do: Central.Communication.PostLib.colours()
  def colours("categories"), do: Central.Communication.CategoryLib.colours()
  def colours("comments"), do: Central.Communication.CommentLib.colours()
  def colours("files"), do: Central.Communication.BlogFileLib.colours()
end
