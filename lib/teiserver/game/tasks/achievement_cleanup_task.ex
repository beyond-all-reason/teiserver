defmodule Teiserver.Game.AchievementCleanupTask do
  use Oban.Worker, queue: :cleanup
  # alias Central.Helpers.TimexHelper
  # alias Teiserver.{Game}
  require Logger

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    # recent_from = Timex.now() |> Timex.shift(hours: -48)

    # brutal_to_normal_scenarios(recent_from)
    :ok
  end

  # def brutal_to_normal_scenarios(from) do
  #   # First build up a list of the achievements that would map to another
  #   normal_scenarios = Game.list_achievement_types(search: [grouping: "Single player scenarios (Normal)"], order_by: "Name (A-Z)", select: [:id])
  #   brutal_scenarios = Game.list_achievement_types(search: [grouping: "Single player scenarios (Brutal)"], order_by: "Name (A-Z)", select: [:id])

  #   id_map = Enum.zip(normal_scenarios, brutal_scenarios)
  #     |> Map.new(fn {norm, brut} ->
  #       {brut.id, norm.id}
  #     end)

  #   # Now get the achievements we might want to map
  #   brutal_ids = Map.keys(id_map)
  #   standard_ids = Map.keys(id_map)

  #   combined_type_ids = Map.keys(id_map) ++ Map.values(id_map)

  #   # We now have a map of {user, achievement_type} -> achievement
  #   achievements = Game.list_user_achievements(search: [
  #     inserted_after: from,
  #     type_id_in: combined_type_ids
  #   ])
  #   |> Map.new(fn a ->
  #     {{a.user_id, a.achievement_type_id}, a}
  #   end)

  #   # Go through
  # end
end
