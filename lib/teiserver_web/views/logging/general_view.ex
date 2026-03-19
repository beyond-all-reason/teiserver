defmodule TeiserverWeb.Logging.GeneralView do
  use TeiserverWeb, :view

  alias Teiserver.Battle.MatchLib
  alias Teiserver.Logging.AggregateViewLogLib
  alias Teiserver.Logging.AuditLogLib
  alias Teiserver.Logging.LoggingLib
  alias Teiserver.Logging.PageViewLogLib
  alias Teiserver.Logging.ServerDayLogLib

  @spec view_colour() :: atom
  def view_colour(), do: LoggingLib.colours()

  @spec icon() :: String.t()
  def icon(), do: LoggingLib.icon()

  @spec view_colour(String.t()) :: atom
  def view_colour("page_view"), do: PageViewLogLib.colours()
  def view_colour("aggregate"), do: AggregateViewLogLib.colours()
  def view_colour("audit"), do: AuditLogLib.colours()
  def view_colour("server"), do: ServerDayLogLib.colours()
  def view_colour("match"), do: MatchLib.colours()
end
