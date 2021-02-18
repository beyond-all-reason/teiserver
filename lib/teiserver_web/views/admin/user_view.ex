defmodule TeiserverWeb.Admin.UserView do
  use TeiserverWeb, :view

  def colours(), do: Teiserver.Account.UserLib.colours()
  def icon(), do: Teiserver.Account.UserLib.icon()
end
