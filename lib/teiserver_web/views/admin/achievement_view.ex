defmodule TeiserverWeb.Admin.AchievementView do
  alias Teiserver.Game.AchievementTypeLib

  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: AchievementTypeLib.colour()

  @spec icon() :: String.t()
  defdelegate icon(), to: AchievementTypeLib
end
