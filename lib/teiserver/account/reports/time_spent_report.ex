defmodule Teiserver.Account.TimeSpentReport do
  alias Central.Helpers.DatePresets
  alias Teiserver.Account

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-satellite-dish"

  @spec run(Plug.Conn.t(), map()) :: {list(), map()}
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
      joins: [:user_stat],
      order_by: {:data, "rank", :desc},
      limit: 100
    )
    |> Enum.sort(fn (user1, user2) ->
      v1 = user1.user_stat.data[params["mode"]]
      v2 = user2.user_stat.data[params["mode"]]
      v1 >= v2
    end)
    |> Enum.filter(fn user ->
      user.user_stat.data["total_minutes"] != nil
    end)

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
      "mode" => "player_minutes"
    }, Map.get(params, "report", %{}))
  end
end
