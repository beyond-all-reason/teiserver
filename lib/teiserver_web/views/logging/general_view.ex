defmodule TeiserverWeb.Logging.GeneralView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour(), do: Teiserver.Logging.LoggingLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Logging.LoggingLib.icon()

  @spec view_colour(String.t()) :: atom
  def view_colour("page_view"), do: Teiserver.Logging.PageViewLogLib.colours()
  def view_colour("aggregate"), do: Teiserver.Logging.AggregateViewLogLib.colours()
  def view_colour("audit"), do: Teiserver.Logging.AuditLogLib.colours()
  def view_colour("error"), do: Teiserver.Logging.ErrorLogLib.colours()
  def view_colour("report"), do: :danger
end
