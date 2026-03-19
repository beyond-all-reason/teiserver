defmodule TeiserverWeb.Admin.AccoladeView do
  use TeiserverWeb, :view

  alias Teiserver.Account.AccoladeLib

  @spec view_colour() :: atom
  def view_colour, do: AccoladeLib.colours()

  @spec icon() :: String.t()
  def icon, do: AccoladeLib.icon()
end
