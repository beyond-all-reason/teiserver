defmodule TeiserverWeb.Admin.BadgeTypeView do
  alias Teiserver.Account.BadgeTypeLib

  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: BadgeTypeLib.colours()

  @spec icon() :: String.t()
  defdelegate icon(), to: BadgeTypeLib

  @spec purpose_list() :: [String.t()]
  defdelegate purpose_list(), to: BadgeTypeLib

  @spec restriction_list() :: [String.t()]
  defdelegate restriction_list(), to: BadgeTypeLib
end
