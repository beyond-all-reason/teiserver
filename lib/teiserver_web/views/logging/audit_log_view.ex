defmodule TeiserverWeb.Logging.AuditLogView do
  use TeiserverWeb, :view

  def view_colour(), do: Teiserver.Logging.AuditLogLib.colours()
  # def gradient(), do: {"#112266", "#6688CC"}
  def icon(), do: Teiserver.Logging.AuditLogLib.icon()
end
