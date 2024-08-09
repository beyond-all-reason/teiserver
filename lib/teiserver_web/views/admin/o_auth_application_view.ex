defmodule TeiserverWeb.Admin.OAuthApplicationView do
  use TeiserverWeb, :view

  import TeiserverWeb.Components.OAuthApplicationComponent
  alias TeiserverWeb.CoreComponents, as: CC
  alias Phoenix.Component, as: Phx

  def view_colour(), do: Teiserver.OAuth.ApplicationLib.colours()
  def icon(), do: Teiserver.OAuth.ApplicationLib.icon()
end
