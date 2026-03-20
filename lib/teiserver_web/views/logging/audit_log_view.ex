defmodule TeiserverWeb.Logging.AuditLogView do
  alias Teiserver.Logging.AuditLogLib

  use TeiserverWeb, :view

  def view_colour, do: AuditLogLib.colours()
  def icon, do: AuditLogLib.icon()
end
