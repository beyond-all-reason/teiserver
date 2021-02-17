defmodule CentralWeb.Communication.CategoryView do
  use CentralWeb, :view

  def colours(), do: Central.Communication.CategoryLib.colours()
  def gradient(), do: {"#000", "#AAA"}
  def icon(), do: Central.Communication.CategoryLib.icon()
end
