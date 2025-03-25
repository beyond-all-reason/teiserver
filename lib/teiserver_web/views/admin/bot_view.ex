defmodule TeiserverWeb.Admin.BotView do
  use TeiserverWeb, :view

  import TeiserverWeb.Components.BotComponent
  alias TeiserverWeb.CoreComponents, as: CC
  alias Phoenix.Component, as: Phx

  def view_colour(), do: Teiserver.BotLib.colours()
  def icon(), do: Teiserver.BotLib.icon()
end
