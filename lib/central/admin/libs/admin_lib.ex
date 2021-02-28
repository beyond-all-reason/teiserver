defmodule Central.Admin.AdminLib do
  use CentralWeb, :library

  def colours(), do: Central.Helpers.StylingHelper.colours(:info2)
  def icon(), do: "fas fa-user-circle"
end
