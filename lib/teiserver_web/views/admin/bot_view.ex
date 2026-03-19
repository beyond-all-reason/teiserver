defmodule TeiserverWeb.Admin.BotView do
  use TeiserverWeb, :view

  import TeiserverWeb.Components.BotComponent
  alias Phoenix.Component, as: Phx
  alias Teiserver.BotLib
  alias TeiserverWeb.CoreComponents, as: CC

  def view_colour(), do: BotLib.colours()
  def icon(), do: BotLib.icon()
end
