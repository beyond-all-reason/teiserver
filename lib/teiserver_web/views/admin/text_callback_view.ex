defmodule TeiserverWeb.Admin.TextCallbackView do
  use TeiserverWeb, :view

  alias Teiserver.Communication.TextCallbackLib

  @spec view_colour() :: atom
  def view_colour, do: TextCallbackLib.colours()

  @spec icon() :: String.t()
  def icon, do: TextCallbackLib.icon()
end
