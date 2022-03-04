defmodule CentralWeb.Logging.GeneralView do
  use CentralWeb, :view

  @spec view_colour() :: atom
  def view_colour(), do: Central.Logging.LoggingLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Central.Logging.LoggingLib.icon()

  @spec view_colour(String.t()) :: atom
  def view_colour("page_view"), do: Central.Logging.PageViewLogLib.colours()
  def view_colour("aggregate"), do: Central.Logging.AggregateViewLogLib.colours()
  def view_colour("audit"), do: Central.Logging.AuditLogLib.colours()
  def view_colour("error"), do: Central.Logging.ErrorLogLib.colours()
  def view_colour("report"), do: :danger
end
