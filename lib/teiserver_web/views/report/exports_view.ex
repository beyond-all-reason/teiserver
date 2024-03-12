defmodule BarserverWeb.Report.ExportsView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :info

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-download"
end
