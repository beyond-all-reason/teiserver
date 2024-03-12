defmodule BarserverWeb.Admin.BadgeTypeView do
  use BarserverWeb, :view

  @spec view_colour() :: atom
  def view_colour(), do: Barserver.Account.BadgeTypeLib.colours()

  @spec icon() :: String.t()
  defdelegate icon(), to: Barserver.Account.BadgeTypeLib

  @spec purpose_list() :: [String.t()]
  defdelegate purpose_list(), to: Barserver.Account.BadgeTypeLib
end
