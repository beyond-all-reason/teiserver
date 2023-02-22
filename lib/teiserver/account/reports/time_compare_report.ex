defmodule Teiserver.Account.TimeCompareReport do
  alias Central.Helpers.DatePresets
  alias Teiserver.{Telemetry, Account}
  alias Central.Helpers.TimexHelper
  import Central.Helpers.StringHelper, only: [get_hash_id: 1]

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-code-compare"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.admin"

  @user_count_max 4

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

    {keys, lines} = get_data(params, {start_date, end_date})

    line_names = lines
      |> Enum.map(fn [name | _] -> name end)

    %{
      user_count_max: @user_count_max,
      keys: keys,
      lines: lines,
      line_names: line_names,
      start_date: start_date || Timex.today(),
      params: params,
      presets: DatePresets.presets()
    }
  end

  defp get_data(_, {nil, _}) do
    {[], %{}}
  end

  defp get_data(params, {start_date, end_date}) do
    user_ids = 1..@user_count_max
      |> Enum.map(fn i ->
        get_hash_id(params["account_user#{i}"])
      end)
      |> Enum.reject(&(&1 == nil))

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
          |> Enum.with_index
          |> Map.new(fn {id, idx} ->
            idx_mod = idx * 0.1

            status = cond do
              cdata == nil -> 0
              Enum.member?(cdata["menu"], id) -> 1 - idx_mod
              Enum.member?(cdata["lobby"], id) -> 2 - idx_mod
              Enum.member?(cdata["spectator"], id) -> 3 - idx_mod
              Enum.member?(cdata["player"], id) -> 4 - idx_mod
              true -> 0
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
            |> Enum.reject(&(&1 == 0))
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
            |> Enum.reject(&(&1 == 0))

          Enum.count(d) >= 2
        end)
    else
      logs
    end

    keys = logs
      |> Enum.map(fn {ts, _} -> TimexHelper.date_to_str(ts, format: :hms) end)

    lines = user_ids
      |> Enum.map(fn userid -> [Account.get_username_by_id(userid) | build_line(logs, userid)] end)

    {keys, lines}
  end

  @spec build_line(list, integer()) :: list()
  defp build_line(logs, userid) do
    logs
      |> Enum.map(fn {_, statuses} -> statuses[userid] end)
  end

  defp apply_defaults(params) do
    acc_values = 1..@user_count_max
      |> Map.new(fn i ->
        {"account_user#{i}", ""}
      end)

    acc_values
    |> Map.merge(%{
      "the_date" => "Today",
      "account_user1" => "#3074 Flaka",
      "account_user2" => "#1332 Flash",
      "account_user3" => "#14643 eL_bArTo",
      "account_user4" => "#2401, Fire[Z]torm_",
      "overlap" => "false",
      "skip_nil" => "false"
    })
    |> Map.merge(Map.get(params, "report", %{}))
  end
end
