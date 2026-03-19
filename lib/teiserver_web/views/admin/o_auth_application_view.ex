defmodule TeiserverWeb.Admin.OAuthApplicationView do
  use TeiserverWeb, :view

  import TeiserverWeb.Components.OAuthApplicationComponent
  alias Phoenix.Component, as: Phx
  alias Teiserver.OAuth.ApplicationLib
  alias TeiserverWeb.CoreComponents, as: CC

  def view_colour(), do: ApplicationLib.colours()
  def icon(), do: ApplicationLib.icon()
end
