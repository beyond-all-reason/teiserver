defmodule TeiserverWeb.Account.SecurityView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :danger

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-lock"
end
