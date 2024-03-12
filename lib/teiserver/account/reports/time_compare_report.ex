defmodule Barserver.Account.TimeCompareReport do
  alias Barserver.{Logging, Account}
  alias Barserver.Helper.TimexHelper
  import Barserver.Helper.StringHelper, only: [get_hash_id: 1]

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-code-compare"

  @spec permissions() :: String.t()
  def permissions(), do: "Moderator"

  @user_count_max 4

  @offline 0
  @menu 1
  @lobby 2
  @spectator 3
  @player 4

  @spec run(Plug.Conn.t(), map()) :: {list(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    {start_date, end_date} =
      case HumanTime.relative(params["the_date"]) do
        {:ok, datetime} ->
          start_date = Timex.beginning_of_day(datetime)
          end_date = Timex.shift(start_date, days: 1)

          {start_date, end_date}

        _ ->
          {nil, nil}
      end

    results = get_data(params, {start_date, end_date})

    Map.merge(results, %{
      user_count_max: @user_count_max,
      start_date: start_date || Timex.today(),
      end_date: end_date,
      params: params
    })
  end

  defp get_data(_, {nil, _}) do
    %{}
  end

  defp get_data(%{"tabular" => "true"} = params, {start_date, end_date}) do
    end_date = end_date |> Timex.shift(days: 7)
    logs = get_logs(params, {start_date, end_date})

    usernames =
      params
      |> get_user_ids()
      |> Map.new(fn userid -> {userid, Account.get_username_by_id(userid)} end)

    stats = get_stats(params, logs)

    %{
      usernames: usernames,
      stats: stats
    }
  end

  defp get_data(params, {start_date, end_date}) do
    logs = get_logs(params, {start_date, end_date})

    keys =
      logs
      |> Enum.map(fn {ts, _} -> TimexHelper.date_to_str(ts, format: :hms) end)

    usernames =
      params
      |> get_user_ids()
      |> Map.new(fn userid -> {userid, Account.get_username_by_id(userid)} end)

    lines =
      params
      |> get_user_ids()
      |> Enum.map(fn userid -> [usernames[userid] | build_line(logs, userid)] end)

    line_names =
      lines
      |> Enum.map(fn [name | _] -> name end)

    stats = get_stats(params, logs)

    %{
      keys: keys,
      lines: lines,
      line_names: line_names,
      usernames: usernames,
      stats: stats
    }
  end

  defp get_user_ids(params) do
    1..@user_count_max
    |> Enum.map(fn i ->
      get_hash_id(params["account_user#{i}"])
    end)
    |> Enum.reject(&(&1 == nil))
  end

  defp get_logs(params, {start_date, end_date}) do
    user_ids = get_user_ids(params)

    logs =
      Logging.list_server_minute_logs(
        search: [
          start_timestamp: start_date,
          end_timestamp: end_date
        ],
        order: "Oldest first",
        limit: 1440
      )
      |> Enum.map(fn log ->
        cdata = log.data["client"]

        userdata =
          user_ids
          |> Enum.with_index()
          |> Map.new(fn {id, idx} ->
            idx_mod = idx * 0.1

            status =
              cond do
                cdata == nil -> @offline
                Enum.member?(cdata["menu"], id) -> @menu - idx_mod
                Enum.member?(cdata["lobby"], id) -> @lobby - idx_mod
                Enum.member?(cdata["spectator"], id) -> @spectator - idx_mod
                Enum.member?(cdata["player"], id) -> @player - idx_mod
                true -> @offline
              end

            {id, status}
          end)

        {
          log.timestamp,
          userdata
        }
      end)

    # Filter out nils?
    logs =
      if params["overlap"] == "true" or params["skip_nil"] == "true" do
        logs
        |> Enum.filter(fn {_, data} ->
          data
          |> Map.values()
          |> Enum.reject(&(&1 == @offline))
          |> Enum.any?()
        end)
      else
        logs
      end

    # Require overlaps?
    if params["overlap"] == "true" do
      logs
      |> Enum.filter(fn {_, data} ->
        d =
          data
          |> Map.values()
          |> Enum.reject(&(&1 == @offline))

        Enum.count(d) >= 2
      end)
    else
      logs
    end
  end

  @spec get_stats(map(), map()) :: any
  defp get_stats(params, logs) do
    user_ids = get_user_ids(params)

    make_combinations(2, user_ids)
    |> Map.new(fn [u1, u2] ->
      {
        {u1, u2},
        stats_for_combo({u1, u2}, logs)
      }
    end)
  end

  defp stats_for_combo({u1, u2}, logs) do
    pairs =
      logs
      |> Enum.map(fn {_, data} -> {round(data[u1]), round(data[u2])} end)

    online_at_same_time =
      pairs
      |> Enum.count(fn
        {@offline, _} -> false
        {_, @offline} -> false
        _ -> true
      end)

    lobby_spec_at_same_time =
      pairs
      |> Enum.count(fn {u1, u2} ->
        u1 + u2 == @player + @spectator
      end)

    %{
      count: Enum.count(pairs),
      online_at_same_time: online_at_same_time,
      lobby_spec_at_same_time: lobby_spec_at_same_time
    }
  end

  @spec build_line(list, integer()) :: list()
  defp build_line(logs, userid) do
    logs
    |> Enum.map(fn {_, statuses} -> statuses[userid] end)
  end

  # First argument is the size of each combination
  # Second is the list of items to make a combination from
  @spec make_combinations(integer(), list) :: [list]
  defp make_combinations(0, _), do: [[]]
  defp make_combinations(_, []), do: []

  defp make_combinations(n, [x | xs]) do
    if n < 0 do
      [[]]
    else
      for(y <- make_combinations(n - 1, xs), do: [x | y]) ++ make_combinations(n, xs)
    end
  end

  defp apply_defaults(params) do
    acc_values =
      1..@user_count_max
      |> Map.new(fn i ->
        {"account_user#{i}", ""}
      end)

    acc_values
    |> Map.merge(%{
      "the_date" => "Yesterday",
      "overlap" => "false",
      "skip_nil" => "false",

      # "account_user1" => "#17899, EvolvedMonkey",
      # "account_user2" => "#1332, Flash",

      "tabular" => "false"
    })
    |> Map.merge(Map.get(params, "report", %{}))
  end
end
