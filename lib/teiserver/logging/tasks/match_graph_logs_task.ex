defmodule Teiserver.Logging.MatchGraphLogsTask do
  @moduledoc false

  @spec perform(list, String.t(), String.t()) :: list()
  def perform(logs, "split", key) do
    [
      {"Duel", "duel.aggregate.#{key}"},
      {"Small Team", "small_team.aggregate.#{key}"},
      {"Large Team", "large_team.aggregate.#{key}"},
      {"FFA", "ffa.aggregate.#{key}"},
      {"Team FFA", "team_ffa.aggregate.#{key}"},
      {"Bot", "bots.aggregate.#{key}"},
      {"Raptors", "raptors.aggregate.#{key}"},
      {"Scavengers", "scavengers.aggregate.#{key}"},
      {"Total", "totals.aggregate.#{key}"}
    ]
    |> Enum.map(fn
      {name, path} ->
        [name | build_line(logs, path)]

      field_name ->
        name =
          String.split(field_name, ".")
          |> Enum.reverse()
          |> hd()

        [name | build_line(logs, field_name)]
    end)
  end

  def perform(logs, "grouped1", key) do
    converted_logs =
      logs
      |> Enum.map(fn l ->
        pvp =
          Map.get(l.data["duel"]["aggregate"], key, 0) +
            Map.get(l.data["ffa"]["aggregate"], key, 0) +
            Map.get(l.data["small_team"]["aggregate"], key, 0) +
            Map.get(l.data["large_team"]["aggregate"], key, 0) +
            Map.get(l.data["team_ffa"]["aggregate"], key, 0)

        pve =
          Map.get(l.data["raptors"]["aggregate"], key, 0) +
            Map.get(l.data["scavengers"]["aggregate"], key, 0)

        new_data =
          Map.merge(l.data, %{
            "pvp" => %{
              "aggregate" => %{
                key => pvp
              }
            },
            "pve" => %{
              "aggregate" => %{
                key => pve
              }
            }
          })

        Map.put(l, :data, new_data)
      end)

    [
      {"PvP", "pvp.aggregate.#{key}"},
      {"PvE", "pve.aggregate.#{key}"},
      {"Bot", "bots.aggregate.#{key}"}
    ]
    |> Enum.map(fn
      {name, path} ->
        [name | build_line(converted_logs, path)]

      field_name ->
        name =
          String.split(field_name, ".")
          |> Enum.reverse()
          |> hd()

        [name | build_line(converted_logs, field_name)]
    end)
  end

  def perform(logs, "grouped2", key) do
    converted_logs =
      logs
      |> Enum.map(fn l ->
        pvp =
          Map.get(l.data["duel"]["aggregate"], key, 0) +
            Map.get(l.data["ffa"]["aggregate"], key, 0) +
            Map.get(l.data["large_team"]["aggregate"], key, 0) +
            Map.get(l.data["small_team"]["aggregate"], key, 0) +
            Map.get(l.data["team_ffa"]["aggregate"], key, 0)

        coop =
          Map.get(l.data["raptors"]["aggregate"], key, 0) +
            Map.get(l.data["scavengers"]["aggregate"], key, 0) +
            Map.get(l.data["bots"]["aggregate"], key, 0)

        new_data =
          Map.merge(l.data, %{
            "pvp" => %{
              "aggregate" => %{
                key => pvp
              }
            },
            "coop" => %{
              "aggregate" => %{
                key => coop
              }
            }
          })

        Map.put(l, :data, new_data)
      end)

    [
      {"PvP", "pvp.aggregate.#{key}"},
      {"Co-op", "coop.aggregate.#{key}"}
    ]
    |> Enum.map(fn
      {name, path} ->
        [name | build_line(converted_logs, path)]

      field_name ->
        name =
          String.split(field_name, ".")
          |> Enum.reverse()
          |> hd()

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
    |> List.flatten()
  end
end
