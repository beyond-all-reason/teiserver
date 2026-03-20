defmodule TeiserverWeb.Admin.CodeView do
  alias Teiserver.Account.CodeLib

  use TeiserverWeb, :view

  @spec view_colour() :: atom()
  def view_colour, do: CodeLib.colours()

  @spec icon() :: String.t()
  def icon, do: CodeLib.icon()
end
