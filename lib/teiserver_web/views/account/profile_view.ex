defmodule TeiserverWeb.Account.ProfileView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :primary

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-user-circle"
end
