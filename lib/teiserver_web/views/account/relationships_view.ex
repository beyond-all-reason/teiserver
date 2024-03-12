defmodule BarserverWeb.Account.RelationshipsView do
  use BarserverWeb, :view

  def view_colour(), do: :info
  def icon(), do: StylingHelper.icon(:info)
end
