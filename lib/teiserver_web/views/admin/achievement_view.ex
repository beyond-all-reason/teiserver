defmodule TeiserverWeb.Admin.AchievementView do
  use TeiserverWeb, :view

  alias Teiserver.Game.AchievementTypeLib

  @spec view_colour() :: atom
  def view_colour(), do: AchievementTypeLib.colour()

  @spec icon() :: String.t()
  defdelegate icon(), to: AchievementTypeLib
end
