defmodule CentralWeb.Admin.ToolView do
  use CentralWeb, :view

  def colours(), do: Central.Admin.ToolLib.colours()
  def icon(), do: Central.Admin.ToolLib.icon()

  def uptime() do
    :os.cmd('uptime')
    |> to_string
  end

  def colours(_), do: Central.Admin.ToolLib.colours()
end
