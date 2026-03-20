defmodule TeiserverWeb.Report.GeneralView do
  alias Teiserver.Account.RatingLib
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Logging.ServerDayLogLib
  alias Teiserver.Telemetry.ComplexClientEventLib
  alias Teiserver.Telemetry.InfologLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour, do: :primary

  @spec icon() :: String.t()
  def icon, do: StylingHelper.icon(:primary)

  @spec view_colour(String.t()) :: atom
  def view_colour("client_events"), do: ComplexClientEventLib.colour()
  def view_colour("server_metrics"), do: ServerDayLogLib.colours()
  def view_colour("match_metrics"), do: MatchLib.colours()
  def view_colour("ratings"), do: RatingLib.colours()
  def view_colour("reports"), do: :danger2
  def view_colour("exports"), do: :info
  def view_colour("infologs"), do: InfologLib.colours()
end
