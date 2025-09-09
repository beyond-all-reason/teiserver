defmodule TeiserverWeb.Admin.AssetView do
  use TeiserverWeb, :view

  import TeiserverWeb.Components.AssetComponents
  alias TeiserverWeb.CoreComponents, as: CC

  def view_colour(), do: Teiserver.AssetLib.colours()
  def icon(), do: Teiserver.AssetLib.icon()
end
