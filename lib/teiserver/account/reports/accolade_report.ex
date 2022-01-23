defmodule Teiserver.Account.AccoladeReport do
  alias Central.Helpers.DatePresets
  alias Teiserver.{Account}
  alias Teiserver.Account.BadgeTypeLib

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

    badge_types = Account.list_badge_types()
    |> Map.new(fn bt -> {bt.id, bt} end)
    |> Map.put(nil, BadgeTypeLib.nil_badge_type())

    accolades = Account.list_accolades(search: [
      inserted_after: start_date |> Timex.to_datetime,
      inserted_before: end_date |> Timex.to_datetime,
    ],
    limit: :infinity)

    counts = accolades
    |> Enum.group_by(fn a ->
      a.badge_type_id
    end, fn _ ->
      1
    end)
    |> Map.new(fn {k, v} -> {k, Enum.count(v)} end)

    assigns = %{
      counts: counts,
      badge_types: badge_types,
      params: params,
      presets: DatePresets.long_ranges()
    }

    {%{
      start_date: start_date,
      end_date: end_date
    }, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(%{
      "date_preset" => "This month",
      "start_date" => "",
      "end_date" => "",
      "mode" => ""
    }, Map.get(params, "report", %{}))
  end
end
