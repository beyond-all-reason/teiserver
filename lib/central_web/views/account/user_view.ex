defmodule CentralWeb.Account.UserView do
  use CentralWeb, :view

  def colours, do: Central.Helpers.StylingHelper.colours(:success)
  def icon, do: "fas fa-user"
  def name, do: "user"
end
