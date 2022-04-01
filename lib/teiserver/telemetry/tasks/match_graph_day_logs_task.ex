defmodule Teiserver.Telemetry.MatchGraphDayLogsTask do
  @spec perform(list, atom) :: list()
  def perform(logs, :split) do
    [
      {"Duel", "duel.aggregate.total_count"},
      {"Team", "team.aggregate.total_count"},
      {"FFA", "ffa.aggregate.total_count"},
      {"Bot", "bots.aggregate.total_count"},
      {"Raptors", "raptors.aggregate.total_count"},
      {"Scavengers", "scavengers.aggregate.total_count"}
    ]
    |> Enum.map(fn
    {name, path} ->
      [name | build_line(logs, path)]
    field_name ->
      name = String.split(field_name, ".")
      |> Enum.reverse()
      |> hd

      [name | build_line(logs, field_name)]
    end)
  end

  def perform(logs, :grouped) do
    converted_logs = logs
    |> Enum.map(fn l ->
      pvp = l.data["duel"]["aggregate"]["total_count"] + l.data["ffa"]["aggregate"]["total_count"] + l.data["team"]["aggregate"]["total_count"]
      pve = l.data["raptors"]["aggregate"]["total_count"] + l.data["scavengers"]["aggregate"]["total_count"]
      # other = l.data["totals"]["aggregate"]["total_count"] - pvp - pve - l.data["bots"]["aggregate"]["total_count"]


      new_data = Map.merge(l.data, %{
        "pvp" => %{
          "aggregate" => %{
            "total_count" => pvp
          }
        },
        "pve" => %{
          "aggregate" => %{
            "total_count" => pve
          }
        },
        # "other" => %{
        #   "aggregate" => %{
        #     "total_count" => other
        #   }
        # }
      })
      Map.put(l, :data, new_data)
    end)

    [
      {"PvP", "pvp.aggregate.total_count"},
      {"PvE", "pve.aggregate.total_count"},
      {"Bot", "bots.aggregate.total_count"},
      # {"Other", "other.aggregate.total_count"},
    ]
    |> Enum.map(fn
    {name, path} ->
      [name | build_line(converted_logs, path)]
    field_name ->
      name = String.split(field_name, ".")
      |> Enum.reverse()
      |> hd

      [name | build_line(converted_logs, field_name)]
    end)
  end

  @spec build_line(list, String.t()) :: list()
  defp build_line(logs, field_name) do
    getter = String.split(field_name, ".")

    logs
    |> Enum.map(fn log ->
      get_in(log.data, getter)
    end)
    |> List.flatten
  end
end
