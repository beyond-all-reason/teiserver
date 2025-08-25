defmodule TeiserverWeb.Admin.UserView do
  use TeiserverWeb, :view
  import TeiserverWeb.PaginationComponents, only: [build_pagination_url: 3, pagination: 1]

  @spec view_colour :: atom()
  def view_colour(), do: Teiserver.Account.UserLib.colours()

  @spec icon :: String.t()
  def icon(), do: Teiserver.Account.UserLib.icon()
end
