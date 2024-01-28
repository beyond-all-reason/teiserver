defmodule BarserverWeb.Admin.AchievementView do
  use BarserverWeb, :view

  @spec view_colour() :: atom
  def view_colour(), do: Barserver.Game.AchievementTypeLib.colour()

  @spec icon() :: String.t()
  defdelegate icon(), to: Barserver.Game.AchievementTypeLib
end
