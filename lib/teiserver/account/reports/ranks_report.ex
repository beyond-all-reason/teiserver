defmodule Teiserver.Account.RanksReport do
  alias Central.Helpers.DatePresets
  alias Teiserver.Account
  alias Central.Helpers.TimexHelper

  @spec icon() :: String.t()
  def icon(), do: "far fa-satellite-dish"

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

    start_date = (Timex.to_unix(start_date) / 60) |> round
    end_date = (Timex.to_unix(end_date) / 60) |> round

    data = Account.list_users(
      search: [
        data_greater_than: {"last_login", start_date |> to_string},
        data_less_than: {"last_login", end_date |> to_string},
        data_equal: {"bot", "false"}
      ],
      order_by: {:data, "ingame_minutes", :desc},
      limit: 100
    )

    assigns = %{
      params: params,
      presets: DatePresets.presets()
    }

    {data, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(%{
      "date_preset" => "This month",
      "start_date" => "",
      "end_date" => "",
      "mode" => ""
    }, params)
  end
end
