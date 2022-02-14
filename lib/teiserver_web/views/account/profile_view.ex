defmodule TeiserverWeb.Account.ProfileView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :primary

  @spec icon() :: String.t()
  def icon(), do: "far fa-user-circle"
end
