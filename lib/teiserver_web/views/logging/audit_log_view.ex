defmodule TeiserverWeb.Logging.AuditLogView do
  alias Teiserver.Logging.AuditLogLib

  use TeiserverWeb, :view

  def view_colour, do: AuditLogLib.colours()
  # def gradient, do: {"#112266", "#6688CC"}
  def icon, do: AuditLogLib.icon()
end
