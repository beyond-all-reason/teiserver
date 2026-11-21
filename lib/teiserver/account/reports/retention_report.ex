defmodule Teiserver.Account.RetentionReport do
  @moduledoc false
  alias Ecto.Type
  alias Teiserver.Account.UserQueries
  alias Teiserver.Logging
  alias Teiserver.Repo

  @spec build_chart(Date.t(), Date.t(), binary() | boolean()) :: tuple()
  def build_chart(start_date, end_date, skip0) do
    skip0 = maybe_cast_boolean(skip0)
    registered_after = DateTime.new!(start_date, ~T"00:00:00")
    registered_before = DateTime.new!(end_date, ~T"00:00:00")

    range_length =
      Date.range(start_date, end_date) |> Enum.count()

    range_length = range_length - 1

    day_logs =
      Logging.list_user_activity_day_logs(
        search: [start_date: start_date, end_date: end_date],
        order: "Newest first",
        limit: :infinity
      )

    accounts =
      UserQueries.users()
      |> UserQueries.where_has_role("Verified")
      |> UserQueries.where_registered_before(registered_before)
      |> UserQueries.where_registered_after(registered_after)
      |> UserQueries.where_logged_in_before(DateTime.utc_now())
      |> Repo.all()
      |> Enum.map(fn user ->
        last_login = user.last_login

        last_played =
          day_logs
          |> Enum.reduce(nil, fn log, acc ->
            case acc do
              nil ->
                if log.data["player"][to_string(user.id)] do
                  log.date
                else
                  nil
                end

              _date ->
                acc
            end
          end)

        if last_played != nil and last_login != nil do
          inserted_date = NaiveDateTime.to_date(user.inserted_at)
          last_login_date = DateTime.to_date(last_login)

          %{
            last_login: Date.diff(inserted_date, last_login_date) |> abs(),
            last_played: Date.diff(inserted_date, last_played) |> abs()
          }
        end
      end)
      |> Enum.reject(&(&1 == nil))

    # Grouping 1 - Last login
    login_retention =
      accounts
      |> Enum.group_by(
        fn %{last_login: value} ->
          value
        end,
        fn _account -> 1 end
      )
      |> Map.new(fn {days, userlist} -> {days, Enum.count(userlist)} end)

    # Grouping 2 - Last time played
    play_retention_grouping =
      accounts
      |> Enum.group_by(
        fn %{last_played: value} ->
          value
        end,
        fn _account -> 1 end
      )
      |> Map.new(fn {days, userlist} -> {days, Enum.count(userlist)} end)

    # Skip0 ?
    login_retention =
      if skip0 do
        login_retention |> Map.put(0, 0)
      else
        login_retention
      end

    play_retention_grouping =
      if skip0 do
        play_retention_grouping |> Map.put(0, 0)
      else
        play_retention_grouping
      end

    chart =
      LiveCharts.build(%{
        id: "retention_report",
        type: :line,
        series: [
          %{name: "Login", data: build_line(login_retention, range_length)},
          %{name: "Play", data: build_line(play_retention_grouping, range_length)}
        ],
        options: %{
          xaxis: %{
            categories: Date.range(start_date, end_date) |> Enum.to_list()
          }
        },
        adapter: LiveCharts.Adapter.ApexCharts
      })

    {chart, Enum.count(accounts)}
  end

  defp maybe_cast_boolean(boolean) when is_binary(boolean) do
    case Type.cast(:boolean, boolean) do
      {:ok, value} ->
        value

      {:error, _reason} ->
        true
    end
  end

  defp maybe_cast_boolean(boolean) when is_boolean(boolean), do: boolean

  defp build_line(value_map, max_key) do
    for key <- Range.new(0, max_key), do: Map.get(value_map, key, 0)
  end
end
