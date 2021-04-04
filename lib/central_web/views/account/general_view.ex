defmodule CentralWeb.Account.GeneralView do
  use CentralWeb, :view

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Helpers.StylingHelper.colours(:info2)

  @spec colours(String.t()) :: {String.t(), String.t(), String.t()}
  def colours("groups"), do: Central.Account.GroupLib.colours()
  def colours("user_configs"), do: Central.Config.UserConfigLib.colours()
  def colours("reports"), do: Central.Account.ReportLib.colours()
end
