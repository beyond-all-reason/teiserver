defmodule TeiserverWeb.Admin.AchievementView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour(), do: Teiserver.Game.AchievementTypeLib.colour()

  @spec icon() :: String.t()
  defdelegate icon(), to: Teiserver.Game.AchievementTypeLib
end
