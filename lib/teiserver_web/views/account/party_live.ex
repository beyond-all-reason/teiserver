defmodule TeiserverWeb.Account.PartyLiveView do
  use TeiserverWeb, :view

  def view_colour(), do: Teiserver.Account.PartyLib.colours()
  def icon(), do: Teiserver.Account.PartyLib.icon()
end
