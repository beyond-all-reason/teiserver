defmodule TeiserverWeb.Admin.TextCallbackView do
  alias Teiserver.Communication.TextCallbackLib

  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: TextCallbackLib.colours()

  @spec icon() :: String.t()
  def icon, do: TextCallbackLib.icon()
end
