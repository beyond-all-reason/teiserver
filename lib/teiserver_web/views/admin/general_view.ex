defmodule TeiserverWeb.Admin.GeneralView do
  use TeiserverWeb, :view

  def colours(), do: StylingHelper.colours(:info)
  def icon(), do: StylingHelper.icon(:info)

  def colours("users"), do: Teiserver.Account.UserLib.colours()
end
