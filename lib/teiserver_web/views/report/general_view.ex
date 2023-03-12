defmodule TeiserverWeb.Report.GeneralView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :primary

  @spec icon() :: String.t()
  def icon(), do: StylingHelper.icon(:primary)

  @spec view_colour(String.t()) :: atom
  def view_colour("client_events"), do: Teiserver.Telemetry.ClientEventLib.colour()
  def view_colour("server_metrics"), do: Teiserver.Telemetry.ServerDayLogLib.colours()
  def view_colour("match_metrics"), do: Teiserver.Battle.MatchLib.colours()
  def view_colour("ratings"), do: Teiserver.Account.RatingLib.colours()
  def view_colour("reports"), do: :danger2
  def view_colour("exports"), do: :info
  def view_colour("infologs"), do: Teiserver.Telemetry.InfologLib.colours()
end
