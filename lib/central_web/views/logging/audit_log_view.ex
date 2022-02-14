defmodule CentralWeb.Logging.AuditLogView do
  use CentralWeb, :view

  def view_colour(), do: Central.Logging.AuditLogLib.colours()
  # def gradient(), do: {"#112266", "#6688CC"}
  def icon(), do: Central.Logging.AuditLogLib.icon()
end
