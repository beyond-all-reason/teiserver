defmodule Teiserver.Game.AchievementCleanupTask do
  use Oban.Worker, queue: :cleanup
  alias Teiserver.{Game}
  require Logger

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    recent_from = Timex.now() |> Timex.shift(hours: -48)

    brutal_to_normal_scenarios(recent_from)
    :ok
  end

  def brutal_to_normal_scenarios(from) do
    # First build up a list of the achievements that would map to another
    normal_scenarios =
      Game.list_achievement_types(
        search: [grouping: "Single player scenarios (Normal)"],
        order_by: "Name (A-Z)",
        select: [:id]
      )

    brutal_scenarios =
      Game.list_achievement_types(
        search: [grouping: "Single player scenarios (Brutal)"],
        order_by: "Name (A-Z)",
        select: [:id]
      )

    id_map =
      Enum.zip(normal_scenarios, brutal_scenarios)
      |> Map.new(fn {norm, brut} ->
        {brut.id, norm.id}
      end)

    # Now get the achievements we might want to map
    brutal_ids = Map.keys(id_map)

    # combined_type_ids = Map.keys(id_map) ++ Map.values(id_map)

    # First, lets get all the brutals
    brutal_achievements =
      Game.list_user_achievements(
        search: [
          inserted_after: from,
          type_id_in: brutal_ids
        ],
        limit: :infinity
      )
      |> Map.new(fn a ->
        {{a.user_id, a.achievement_type_id}, a}
      end)

    # Now get the users from that and then get their normals
    user_ids =
      brutal_achievements
      |> Enum.map(fn {{user_id, _}, _} -> user_id end)
      |> Enum.uniq()

    # Next up we want to limit the normal_ids based on
    # the brutals we actually found
    normal_ids =
      brutal_achievements
      |> Enum.map(fn {{_, type_id}, _} -> id_map[type_id] end)
      |> Enum.uniq()

    # Normals
    normal_achievements =
      Game.list_user_achievements(
        search: [
          user_id_in: user_ids,
          type_id_in: normal_ids
        ],
        select: [:user_id, :achievement_type_id],
        limit: :infinity
      )
      |> Enum.map(fn a ->
        {a.user_id, a.achievement_type_id}
      end)

    # Now anywhere there's not a normal for a brutal we add the normal
    normals_to_add =
      brutal_achievements
      |> Enum.filter(fn {{user_id, achievement_type_id}, _} ->
        key = {user_id, id_map[achievement_type_id]}
        not Enum.member?(normal_achievements, key)
      end)
      |> Enum.map(fn {_, a} ->
        %{
          user_id: a.user_id,
          achievement_type_id: id_map[a.achievement_type_id],
          achieved: true,
          inserted_at: a.inserted_at
        }
      end)

    # Now add them!
    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(:insert_all, Game.UserAchievement, normals_to_add)
    |> Central.Repo.transaction()
  end
end
