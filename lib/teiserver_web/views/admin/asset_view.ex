defmodule TeiserverWeb.Admin.AssetView do
  use TeiserverWeb, :view

  alias TeiserverWeb.CoreComponents, as: CC
  alias Phoenix.Component, as: Phx

  def view_colour(), do: Teiserver.AssetLib.colours()
  def icon(), do: Teiserver.AssetLib.icon()
end
