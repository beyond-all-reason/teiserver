defmodule TeiserverWeb.Admin.UserView do
  use TeiserverWeb, :view
  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  alias Teiserver.Account.UserLib

  @spec view_colour :: atom()
  def view_colour(), do: UserLib.colours()

  @spec icon :: String.t()
  def icon(), do: UserLib.icon()
end
