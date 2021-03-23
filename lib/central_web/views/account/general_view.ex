defmodule CentralWeb.Account.GeneralView do
  use CentralWeb, :view

  def colours(), do: Central.Helpers.StylingHelper.colours(:info2)

  def colours("groups"), do: Central.Account.GroupLib.colours()
  def colours("user_configs"), do: Central.Config.UserConfigLib.colours()
  def colours("reports"), do: Central.Account.ReportLib.colours()
end
