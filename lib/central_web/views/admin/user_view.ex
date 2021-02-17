defmodule CentralWeb.Admin.UserView do
  use CentralWeb, :view

  def colours(), do: Central.Account.UserLib.colours()
  def icon(), do: Central.Account.UserLib.icon()
end
