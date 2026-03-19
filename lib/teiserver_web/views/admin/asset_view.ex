defmodule TeiserverWeb.Admin.AssetView do
  use TeiserverWeb, :view

  import TeiserverWeb.Components.AssetComponents
  alias Teiserver.AssetLib
  alias TeiserverWeb.CoreComponents, as: CC

  def view_colour(), do: AssetLib.colours()
  def icon(), do: AssetLib.icon()
end
