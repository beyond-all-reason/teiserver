defmodule BarserverWeb.Account.SecurityView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :danger

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-lock"
end
