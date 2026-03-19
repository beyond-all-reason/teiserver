defmodule TeiserverWeb.Admin.CodeView do
  use TeiserverWeb, :view

  alias Teiserver.Account.CodeLib

  @spec view_colour() :: atom()
  def view_colour(), do: CodeLib.colours()

  @spec icon() :: String.t()
  def icon(), do: CodeLib.icon()
end
