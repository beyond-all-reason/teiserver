defmodule Teiserver.Account.TimeCompareReport do
  alias Central.Helpers.DatePresets
  alias Teiserver.{Telemetry, Account}
  alias Central.Helpers.TimexHelper
  import Central.Helpers.StringHelper, only: [get_hash_id: 1]

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-code-compare"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.admin"

  @spec run(Plug.Conn.t(), map()) :: {list(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    {start_date, end_date} = case HumanTime.relative(params["the_date"]) do
      {:ok, datetime} ->
        start_date = Timex.beginning_of_day(datetime)
        end_date = Timex.shift(start_date, days: 1)

        {start_date, end_date}

      _ ->
        {nil, nil}
    end

    {data, user_ids, users} = get_data(params, {start_date, end_date})

    %{
      data: data,
      user_ids: user_ids,
      users: users,
      start_date: start_date || Timex.today(),
      params: params,
      presets: DatePresets.presets()
    }
  end

  defp get_data(_, {nil, _}) do
    {[], %{}}
  end

  defp get_data(params, {start_date, end_date}) do
    userid1 = get_hash_id(params["account_user1"])
    userid2 = get_hash_id(params["account_user2"])

    user_ids = [userid1, userid2]
      |> Enum.reject(&(&1 == nil))

    users = user_ids
      |> Account.list_users_from_cache()
      |> Map.new(fn user -> {user.id, user} end)

    logs = Telemetry.list_server_minute_logs(
      search: [
        start_timestamp: start_date,
        end_timestamp: end_date
      ],
      order: "Oldest first",
      limit: 1440
    )
      |> Enum.map(fn log ->
        cdata = log.data["client"]

        userdata = user_ids
          |> Map.new(fn id ->
            status = cond do
              cdata == nil -> :offline
              Enum.member?(cdata["lobby"], id) -> :lobby
              Enum.member?(cdata["menu"], id) -> :menu
              Enum.member?(cdata["player"], id) -> :player
              Enum.member?(cdata["spectator"], id) -> :spectator
              true -> :offline
            end

            {id, status}
          end)

        {
          log.timestamp,
          userdata
        }
      end)

    # Filter out nils?
    logs = if params["overlap"] == "true" or params["skip_nil"] == "true" do
      logs
        |> Enum.filter(fn {_, data} ->
          data
            |> Map.values
            |> Enum.reject(&(&1 == :offline))
            |> Enum.any?
        end)
    else
      logs
    end

    # Require overlaps?
    logs = if params["overlap"] == "true" do
      logs
        |> Enum.filter(fn {_, data} ->
          d = data
            |> Map.values
            |> Enum.reject(&(&1 == :offline))

          Enum.count(d) >= 2
        end)
    else
      logs
    end

    IO.puts ""
    IO.inspect logs
    IO.puts ""

    {logs, user_ids, users}
  end

  defp apply_defaults(params) do
    Map.merge(%{
      "the_date" => "Today",
      "account_user1" => "#3074 Flaka",
      "account_user2" => "#1332 Flash",
      "overlap" => "true",
      "skip_nil" => "true"
    }, Map.get(params, "report", %{}))
  end
end
