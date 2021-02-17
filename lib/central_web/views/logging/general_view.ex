defmodule CentralWeb.Logging.GeneralView do
  use CentralWeb, :view

  def colours(), do: Central.Logging.LoggingLib.colours()
  def icon(), do: Central.Logging.LoggingLib.icon()

  def colours("page_view"), do: Central.Logging.PageViewLogLib.colours()
  def colours("aggregate"), do: Central.Logging.AggregateViewLogLib.colours()
  def colours("audit"), do: Central.Logging.AuditLogLib.colours()
  def colours("report"), do: Central.Helpers.StylingHelper.colours(:report)
end
