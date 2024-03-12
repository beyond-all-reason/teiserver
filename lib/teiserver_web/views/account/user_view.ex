defmodule BarserverWeb.Account.UserView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour, do: :success

  @spec icon :: String.t()
  def icon, do: "fa-solid fa-user"

  @spec name :: String.t()
  def name, do: "user"
end
