defmodule TeiserverWeb.Admin.AssetView do
  alias Teiserver.AssetLib
  alias TeiserverWeb.CoreComponents, as: CC

  use TeiserverWeb, :view

  import TeiserverWeb.Components.AssetComponents

  def view_colour(), do: AssetLib.colours()
  def icon(), do: AssetLib.icon()
end
