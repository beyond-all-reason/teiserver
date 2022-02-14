defmodule CentralWeb.Account.UserView do
  use CentralWeb, :view

  @spec view_colour :: atom
  def view_colour, do: :success

  @spec icon :: String.t()
  def icon, do: "fas fa-user"

  @spec name :: String.t()
  def name, do: "user"
end
