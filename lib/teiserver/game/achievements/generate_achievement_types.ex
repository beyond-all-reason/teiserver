defmodule Teiserver.Game.GenerateAchievementTypes do
  alias Teiserver.Game

  @spec perform() :: :ok
  def perform() do
    existing_types = Game.list_achievement_types(limit: :infinity, select: [:name])
      |> Enum.map(fn %{name: name} -> name end)

    [
      # duel_battle_wins([5, 25, 100]),
      # team_battle_wins([5, 25, 100]),
      # ffa_battle_wins([5, 25, 100]),
      scenarios(),
    ]
    |> List.flatten
    |> Enum.filter(fn %{name: name} ->
      not Enum.member?(existing_types, name)
    end)
    |> Enum.each(fn data ->
      Game.create_achievement_type(data)
    end)

    :ok
  end

  defp scenarios() do
    scenarios = [
      %{base_name: "001 - A helping hand"},
      %{base_name: "002 - A head start"},
      %{base_name: "003 - Testing the waters"},
      %{base_name: "004 - A safe haven"},
      %{base_name: "005 - Mines, all mine!"},
      %{base_name: "006 - Back from the dead"},
      %{base_name: "007 - King of the hill"},
      %{base_name: "008 - Keep your secrets"},
      %{base_name: "009 - Outsmart the barbarians"},
      %{base_name: "010 - World war XXV"},
      %{base_name: "011 - Steal Cortex's tech"},
      %{base_name: "012 - One robot army"},
      %{base_name: "013 - One by one"},
      %{base_name: "014 - The sky is the limit"},
      %{base_name: "015 - David vs Goliath"},
      %{base_name: "016 - A final stand"},
      %{base_name: "017 - Infantry simulator"},
      %{base_name: "018 - Tick tock"},
      %{base_name: "019 - Catch those rare comets"},
    ]

    normal = scenarios
      |> Enum.map(fn data ->
        Map.merge(%{
          name: data.base_name <> " (Normal)",
          grouping: "Single player scenarios (Normal)",
          icon: "fa-solid fa-pig",
          colour: "#777777",
          description: "Win the scenario #{data.base_name} on Normal"
        }, data)
      end)

    brutal = scenarios
      |> Enum.map(fn data ->
        Map.merge(%{
          name: data.base_name <> " (Brutal)",
          grouping: "Single player scenarios (Brutal)",
          icon: "fa-solid fa-elephant",
          colour: "#AA6666",
          description: "Win the scenario #{data.base_name} on Brutal"
        }, data)
      end)

    normal ++ brutal
  end

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
