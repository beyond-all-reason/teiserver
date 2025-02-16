defmodule TeiserverWeb.Admin.BadgeTypeView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour(), do: Teiserver.Account.BadgeTypeLib.colours()

  @spec icon() :: String.t()
  defdelegate icon(), to: Teiserver.Account.BadgeTypeLib

  @spec purpose_list() :: [String.t()]
  defdelegate purpose_list(), to: Teiserver.Account.BadgeTypeLib

  @spec restriction_list() :: [String.t()]
  defdelegate restriction_list(), to: Teiserver.Account.BadgeTypeLib
end
