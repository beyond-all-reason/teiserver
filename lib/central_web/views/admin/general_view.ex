defmodule CentralWeb.Admin.GeneralView do
  use CentralWeb, :view
  use Timex

  @build_time_priv Timex.now()

  def build_time() do
    @build_time_priv
  end

  def colours(), do: Central.Admin.AdminLib.colours()
  def icon(), do: Central.Admin.AdminLib.icon()

  def colours("user"), do: Central.Account.UserLib.colours()
  def colours("group"), do: Central.Account.GroupLib.colours()
  def colours("reports"), do: Central.Account.ReportLib.colours()
  def colours("tool"), do: Central.Admin.ToolLib.colours()
end
