defmodule TeiserverWeb.Logging.AuditLogView do
  use TeiserverWeb, :view

  alias Teiserver.Logging.AuditLogLib

  def view_colour(), do: AuditLogLib.colours()
  # def gradient(), do: {"#112266", "#6688CC"}
  def icon(), do: AuditLogLib.icon()
end
