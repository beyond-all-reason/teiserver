defmodule CentralWeb.Logging.GeneralView do
  use CentralWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Logging.LoggingLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Central.Logging.LoggingLib.icon()

  @spec colours(String.t()) :: {String.t(), String.t(), String.t()}
  def colours("page_view"), do: Central.Logging.PageViewLogLib.colours()
  def colours("aggregate"), do: Central.Logging.AggregateViewLogLib.colours()
  def colours("audit"), do: Central.Logging.AuditLogLib.colours()
  def colours("error"), do: Central.Logging.ErrorLogLib.colours()
  def colours("report"), do: Central.Helpers.StylingHelper.colours(:report)
end
