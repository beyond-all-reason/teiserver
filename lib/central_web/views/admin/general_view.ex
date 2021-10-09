defmodule CentralWeb.Admin.GeneralView do
  use CentralWeb, :view
  use Timex

  @build_time_priv Timex.now()

  def build_time() do
    @build_time_priv
  end

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Admin.AdminLib.colours()
  @spec icon() :: String.t()
  def icon(), do: Central.Admin.AdminLib.icon()

  @spec colours(String.t()) :: {String.t(), String.t(), String.t()}
  def colours("user"), do: Central.Account.UserLib.colours()
  def colours("group"), do: Central.Account.GroupLib.colours()
  def colours("reports"), do: Central.Account.ReportLib.colours()
  def colours("codes"), do: Central.Account.CodeLib.colours()
  def colours("site_config"), do: Central.Config.SiteConfigLib.colours()
  def colours("tool"), do: Central.Admin.ToolLib.colours()
end
