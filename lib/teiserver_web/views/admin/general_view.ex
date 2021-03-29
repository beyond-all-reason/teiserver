defmodule TeiserverWeb.Admin.GeneralView do
  use TeiserverWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours(), do: StylingHelper.colours(:info)
  @spec icon() :: String.t()
  def icon(), do: StylingHelper.icon(:info)

  @spec colours(String.t()) :: {String.t(), String.t(), String.t()}
  def colours("clients"), do: Teiserver.ClientLib.colours()
  def colours("users"), do: Teiserver.Account.UserLib.colours()
end
