defmodule TeiserverWeb.Admin.BadgeTypeView do
  use TeiserverWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  defdelegate colours(), to: Teiserver.Account.BadgeTypeLib

  @spec icon() :: String.t()
  defdelegate icon(), to: Teiserver.Account.BadgeTypeLib

  @spec purpose_list() :: [String.t()]
  defdelegate purpose_list(), to: Teiserver.Account.BadgeTypeLib
end
