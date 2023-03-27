defmodule Teiserver.Moderation.ActivityReport do
  alias Central.Helpers.DatePresets
  alias Teiserver.Moderation
  alias Central.Repo

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Moderation.BanLib.icon()

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.staff.moderator"

  @top_count 3

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


    %{
      start_date: start_date,
      end_date: end_date,
      params: params,
      presets: DatePresets.long_ranges()
    }
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
end
