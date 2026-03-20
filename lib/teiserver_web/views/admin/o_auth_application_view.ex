defmodule TeiserverWeb.Admin.OAuthApplicationView do
  alias Phoenix.Component, as: Phx
  alias Teiserver.OAuth.ApplicationLib
  alias TeiserverWeb.CoreComponents, as: CC

  use TeiserverWeb, :view

  import TeiserverWeb.Components.OAuthApplicationComponent

  def view_colour, do: ApplicationLib.colours()
  def icon, do: ApplicationLib.icon()
end
