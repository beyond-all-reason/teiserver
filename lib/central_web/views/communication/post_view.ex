defmodule CentralWeb.Communication.PostView do
  use CentralWeb, :view

  def colours(), do: Central.Communication.PostLib.colours()
  def gradient(), do: {"#000", "#AAA"}
  def icon(), do: Central.Communication.PostLib.icon()

  def get_key(url_slug), do: Central.Communication.PostLib.get_key(url_slug)
end
