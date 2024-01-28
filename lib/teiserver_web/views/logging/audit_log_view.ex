defmodule BarserverWeb.Logging.AuditLogView do
  use BarserverWeb, :view

  def view_colour(), do: Barserver.Logging.AuditLogLib.colours()
  # def gradient(), do: {"#112266", "#6688CC"}
  def icon(), do: Barserver.Logging.AuditLogLib.icon()
end
