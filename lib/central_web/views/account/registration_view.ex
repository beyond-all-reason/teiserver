defmodule CentralWeb.Account.RegistrationView do
  use CentralWeb, :view

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:primary)
end
