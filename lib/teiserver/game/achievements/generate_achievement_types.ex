defmodule Teiserver.Game.GenerateAchievementTypes do
  alias Teiserver.Game

  @spec perform() :: :ok
  def perform(), do: :ok

  # def perform(_) do
  #   existing_types = Game.list_achievement_types(limit: :infinity, select: :name)
  #     |> Enum.map(fn %{name: name} -> name end)

  #   full_types = [
  #     duel_battle_wins([5, 25, 100]),
  #     team_battle_wins([5, 25, 100]),
  #     ffa_battle_wins([5, 25, 100]),
  #   ]
  #   |> List.flatten
  #   |> Enum.filter(fn %{name: name} ->
  #     not Enum.member?(existing_types, name)
  #   end)
  #   |> Enum.each(fn data ->
  #     Game.create_achievement(data)
  #   end)

  #   :ok
  # end

  # defp duel_battle_wins(counts) do
  #   counts
  #   |> Enum.map(fn c ->
  #     %{
  #       name: "Win #{c} duel battles",
  #       grouping: "Duel battles",
  #       icon: "",
  #       colour: "",
  #       description: ""
  #     }
  #   end)
  # end

  # defp ffa_battle_wins(counts) do
  #   counts
  #   |> Enum.map(fn c ->
  #     %{
  #       name: "Win #{c} ffa battles",
  #       grouping: "FFA battles",
  #       icon: "",
  #       colour: "",
  #       description: ""
  #     }
  #   end)
  # end

  # defp team_battle_wins(counts) do
  #   counts
  #   |> Enum.map(fn c ->
  #     %{
  #       name: "Win #{c} team battles",
  #       grouping: "Team battles",
  #       icon: "",
  #       colour: "",
  #       description: ""
  #     }
  #   end)
  # end
end
