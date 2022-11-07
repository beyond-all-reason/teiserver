defmodule TeiserverWeb.Moderation.ReportFormView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Account.UserLib.colour()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Account.UserLib.icon()
end
