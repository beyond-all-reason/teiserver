defmodule Teiserver.Account.ActiveReport do
  alias Teiserver.Helper.DatePresets
  alias Teiserver.{Logging}

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-satellite-dish"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    # Date range
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    player_counts =
      Logging.list_user_activity_day_logs(
        search: [
          start_date: start_date,
          end_date: end_date
        ],
        order: "Newest first",
        limit: :infinity
      )
      |> Enum.reduce(%{}, fn log, players_acc ->
        log.data["player"]
        |> Enum.reduce(players_acc, fn {player_id, minutes}, acc ->
          existing = Map.get(acc, player_id, 0)
          Map.put(acc, player_id, existing + minutes)
        end)
      end)
      |> Enum.group_by(
        fn {_, v} ->
          get_grouping(v)
        end,
        fn {k, _} ->
          k
        end
      )
      |> Enum.map(fn {group, players} ->
        {group, Enum.count(players)}
      end)

    cumulative_player_counts =
      player_counts
      |> Map.new()
      |> Map.keys()
      |> Enum.map(fn key ->
        v =
          player_counts
          |> Enum.filter(fn {k, _} -> k >= key end)
          |> Enum.map(fn {_, v} -> v end)
          |> Enum.sum()

        {key, v}
      end)
      |> Map.new()

    # If we run this at the start of the month it'll error
    total_player_count = if Enum.empty?(cumulative_player_counts) do
      0
    else
      cumulative_player_counts
        |> Map.values()
        |> Enum.max
    end

    assigns = %{
      params: params,
      presets: DatePresets.long_ranges()
    }

    {%{
       player_counts: player_counts,
       cumulative_player_counts: cumulative_player_counts,
       total_player_count: total_player_count,
       start_date: start_date,
       end_date: end_date
     }, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "date_preset" => "This month",
        "start_date" => "",
        "end_date" => "",
        "mode" => ""
      },
      Map.get(params, "report", %{})
    )
  end

  defp get_grouping(v) do
    v = v / 60

    cond do
      v < 1 -> 1
      v < 3 -> 3
      v < 5 -> 5
      v < 10 -> 10
      v < 15 -> 15
      v < 30 -> 30
      v < 50 -> 50
      v < 100 -> 100
      v < 250 -> 250
      v < 500 -> 500
      v < 1000 -> 1000
      v < 3000 -> 3000
      true -> nil
    end
  end
end
