defmodule BarserverWeb.Report.GeneralView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :primary

  @spec icon() :: String.t()
  def icon(), do: StylingHelper.icon(:primary)

  @spec view_colour(String.t()) :: atom
  def view_colour("client_events"), do: Barserver.Telemetry.ComplexClientEventLib.colour()
  def view_colour("server_metrics"), do: Barserver.Logging.ServerDayLogLib.colours()
  def view_colour("match_metrics"), do: Barserver.Battle.MatchLib.colours()
  def view_colour("ratings"), do: Barserver.Account.RatingLib.colours()
  def view_colour("reports"), do: :danger2
  def view_colour("exports"), do: :info
  def view_colour("infologs"), do: Barserver.Telemetry.InfologLib.colours()
end
