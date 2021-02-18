defmodule TeiserverWeb.Account.GeneralView do
  use TeiserverWeb, :view

  def colours(), do: StylingHelper.colours(:success)
  def icon(), do: StylingHelper.icon(:success)
end
