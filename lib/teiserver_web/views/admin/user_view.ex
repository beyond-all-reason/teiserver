defmodule TeiserverWeb.Admin.UserView do
  use TeiserverWeb, :view
  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  @spec view_colour :: atom()
  def view_colour(), do: Teiserver.Account.UserLib.colours()

  @spec icon :: String.t()
  def icon(), do: Teiserver.Account.UserLib.icon()
end
