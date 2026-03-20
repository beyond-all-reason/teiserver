defmodule TeiserverWeb.Admin.AccoladeView do
  alias Teiserver.Account.AccoladeLib

  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: AccoladeLib.colours()

  @spec icon() :: String.t()
  def icon, do: AccoladeLib.icon()
end
