defmodule Teiserver.Moderation.ActivityReport do
  alias Teiserver.Helper.DatePresets
  alias Teiserver.Moderation
  alias Teiserver.Helper.TimexHelper

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Moderation.BanLib.icon()

  @spec permissions() :: String.t()
  def permissions(), do: "Overwatch"

  @spec run(Plug.Conn.t(), map()) :: map()
  def run(_conn, params) do
    params = apply_defaults(params)

    # Date range
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    permanent = Timex.now() |> Timex.shift(years: 100)

    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    reports = get_reports(start_date, end_date)
    actions = get_actions(start_date, end_date)

    dates =
      TimexHelper.make_date_series(:days, start_date, end_date)
      |> Enum.map(&Timex.to_date/1)

    date_strs =
      dates
      |> Enum.map(fn d ->
        TimexHelper.date_to_str(d, format: :ymd)
      end)

    report_data = {
      date_strs,
      [
        ["Total reports" | build_line(dates, reports, fn _ -> true end)],
        ["Actioned reports" | build_line(dates, reports, fn r -> r.result_id != nil end)]
      ]
    }

    action_data = {
      date_strs,
      [
        [
          "Warnings"
          | build_line(dates, actions, fn a ->
              Enum.member?(a.restrictions, "Warning reminder")
            end)
        ],
        [
          "Mutes"
          | build_line(dates, actions, fn a -> Enum.member?(a.restrictions, "All chat") end)
        ],
        [
          "Suspensions"
          | build_line(dates, actions, fn a ->
              Enum.member?(a.restrictions, "Login") and Timex.compare(a.expires, permanent) == -1
            end)
        ],
        [
          "Bans"
          | build_line(dates, actions, fn a ->
              Enum.member?(a.restrictions, "Login") and Timex.compare(a.expires, permanent) == 1
            end)
        ]
      ]
    }

    data = %{
      actions: action_data,
      reports: report_data
    }

    %{
      data: data,
      start_date: start_date,
      end_date: end_date,
      params: params,
      presets: DatePresets.long_ranges()
    }
  end

  defp get_reports(start_date, end_date) do
    Moderation.list_reports(
      search: [
        inserted_after: start_date,
        inserted_before: end_date
      ],
      limit: :infinity
    )
    |> Enum.group_by(fn report ->
      report.inserted_at |> Timex.to_date()
    end)
  end

  defp get_actions(start_date, end_date) do
    Moderation.list_actions(
      search: [
        inserted_after: start_date,
        inserted_before: end_date,
        not_in_restrictions: ["Bridging"]
      ],
      limit: :infinity
    )
    |> Enum.group_by(fn action ->
      action.inserted_at |> Timex.to_date()
    end)
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "date_preset" => "This month",
        "start_date" => "",
        "end_date" => "",
        "mode" => "",
        "columns" => "1"
      },
      Map.get(params, "report", %{})
    )
  end

  @spec build_line(list, map, function()) :: list()
  def build_line(key_list, object_map, filter_func) do
    key_list
    |> Enum.map(fn key ->
      Map.get(object_map, key, [])
      |> Enum.count(filter_func)
    end)
  end
end
