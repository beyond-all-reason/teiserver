defmodule TeiserverWeb.Account.GeneralView do
  use TeiserverWeb, :view

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: StylingHelper.colours(:success)

  @spec icon() :: String.t()
  def icon(), do: "fas fa-user"

  @spec colours(String.t()) :: {String.t(), String.t(), String.t()}
  def colours("profile"), do: StylingHelper.colours(:primary)
  def colours("relationships"), do: StylingHelper.colours(:info)
  def colours("customisation"), do: Central.Config.UserConfigLib.colours()
  def colours("preferences"), do: Central.Config.UserConfigLib.colours()
  def colours("clans"), do: Teiserver.Clans.ClanLib.colours()
end
