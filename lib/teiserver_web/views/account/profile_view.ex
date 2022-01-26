defmodule TeiserverWeb.Account.ProfileView do
  use TeiserverWeb, :view

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: StylingHelper.colours(:primary)

  @spec icon() :: String.t()
  def icon(), do: "far fa-user-circle"
end
