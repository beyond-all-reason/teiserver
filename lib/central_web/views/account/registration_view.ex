defmodule CentralWeb.Account.RegistrationView do
  use CentralWeb, :view

  def colours, do: Central.Helpers.StylingHelper.colours(:primary)
end
