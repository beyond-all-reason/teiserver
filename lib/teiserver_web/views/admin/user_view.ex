defmodule TeiserverWeb.Admin.UserView do
  alias Teiserver.Account.UserLib

  use TeiserverWeb, :view

  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  @spec view_colour :: atom()
  def view_colour(), do: UserLib.colours()

  @spec icon :: String.t()
  def icon(), do: UserLib.icon()
end
