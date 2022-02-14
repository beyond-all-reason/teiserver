defmodule TeiserverWeb.Account.RelationshipsView do
  use TeiserverWeb, :view

  def view_colour(), do: :info
  def icon(), do: StylingHelper.icon(:info)
end
