defmodule TeiserverWeb.Admin.BotView do
  alias Phoenix.Component, as: Phx
  alias Teiserver.BotLib
  alias TeiserverWeb.CoreComponents, as: CC

  use TeiserverWeb, :view

  import TeiserverWeb.Components.BotComponent

  def view_colour, do: BotLib.colours()
  def icon, do: BotLib.icon()
end
