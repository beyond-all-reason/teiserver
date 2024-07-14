defmodule TeiserverWeb.Admin.AutohostView do
  use TeiserverWeb, :view

  import TeiserverWeb.Components.AutohostComponent
  alias TeiserverWeb.CoreComponents, as: CC
  alias Phoenix.Component, as: Phx

  def view_colour(), do: Teiserver.AutohostLib.colours()
  def icon(), do: Teiserver.AutohostLib.icon()
end
