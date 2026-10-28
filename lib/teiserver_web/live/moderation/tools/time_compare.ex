defmodule TeiserverWeb.ModerationLive.Tools.TimeCompare do
  @moduledoc false
  alias Ecto.Adapters.SQL
  alias Teiserver.Account
  alias Teiserver.Helper.DateHelper
  alias Teiserver.Helper.StringHelper
  alias Teiserver.Repo
  alias TeiserverWeb.ModerationLive.ToolsComponents

  use TeiserverWeb, :live_view

  @user_count_max 3

  @offline 0
  @menu 1
  @lobby 2
  @spectator 3
  @player 4

  @impl LiveView
  def mount(_params, _session, %Socket{} = socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(params, _url, %Socket{} = socket) when is_connected?(socket) do
    search = apply_default_params(params)

    socket
    |> assign(
      page_title: "Time compare",
      search: search,
      form: to_form(search),
      user_count_max: @user_count_max,
      connected?: true
    )
    |> get_data()
    |> noreply()
  end

  def handle_params(_params, _url, %Socket{} = socket) do
    socket
    |> assign(connected?: false)
    |> noreply()
  end

  @impl LiveView
  def handle_event("1-day-earlier", _params, %Socket{assigns: assigns} = socket) do
    new_search =
      Map.merge(assigns.search, %{
        "date" => Date.add(assigns.search["date"], -1)
      })

    new_form = to_form(new_search)

    socket
    |> assign(search: new_search, form: new_form)
    |> get_data()
    |> noreply()
  end

  def handle_event("1-day-later", _params, %Socket{assigns: assigns} = socket) do
    new_search =
      Map.merge(assigns.search, %{
        "date" => Date.add(assigns.search["date"], 1)
      })

    new_form = to_form(new_search)

    socket
    |> assign(search: new_search, form: new_form)
    |> get_data()
    |> noreply()
  end

  def handle_event("update", params, %Socket{assigns: assigns} = socket) do
    params = convert_search_params(params)
    new_search = Map.merge(assigns.search, params)

    socket
    |> assign(search: new_search)
    |> get_data()
    |> noreply()
  end

  defp apply_default_params(params) do
    acc_values =
      1..@user_count_max
      |> Map.new(fn i ->
        key = "user#{i}"
        {key, params[key]}
      end)

    date = DateHelper.parse_ymd(params["date"]) || Date.utc_today()

    acc_values
    |> Map.merge(%{
      "date" => date,
      "include_nil" => "false"
    })
    |> Map.merge(params)
    |> convert_search_params()
  end

  defp convert_search_params(params) do
    changed_params =
      %{
        "date" => DateHelper.parse_ymd(params["date"]),
        "include_nil" => params["include_nil"] == "true"
      }
      |> Map.filter(fn {_key, v} -> not is_nil(v) end)

    Map.merge(params, changed_params)
  end

  defp get_data(%Socket{assigns: %{search: params}} = socket) do
    user_ids = get_user_ids(params)
    logs = get_logs(params, user_ids)

    has_data? = not Enum.empty?(logs)

    usernames =
      params
      |> get_user_ids()
      |> Enum.with_index()
      |> Map.new(fn {userid, idx} -> {idx, Account.get_username_by_id(userid)} end)

    {times, cdata} =
      logs
      |> Enum.unzip()

    series =
      cdata
      |> Enum.zip()
      |> Enum.map(&Tuple.to_list/1)
      |> Enum.with_index()
      |> Enum.map(fn {data, idx} ->
        %{name: usernames[idx], data: data}
      end)

    chart =
      LiveCharts.build(%{
        # Set the chart type. Supports `:line`, `:bar`, `:pie`, `:donut`,
        # `:area`, and many more. For a full list of supported types, see the
        # adapter or JS library documentation.
        type: :line,

        # A list of series data with all the datapoints to chart. Format of
        # this data is determined by the adapter/JS library. This may also
        # be empty, if you plan to push dynamic updates to the chart over
        # the socket later.
        series: series,

        # (Optional) Other library and adapter-specific options.
        options: %{
          xaxis: %{
            categories: times
          }
        },

        # (Optional) set the adapter to use for the chart. If not set, uses
        # the global adapter configured in `config.exs` (defaults to
        # `LiveCharts.Adapter.ApexCharts`).
        adapter: LiveCharts.Adapter.ApexCharts
      })

    socket
    |> assign(chart: chart)
    |> assign(has_data?: has_data?)
  end

  # If no user ids are supplied we don't want to bother running any queries
  defp get_logs(_params, []) do
    []
  end

  defp get_logs(params, user_ids) do
    # Allows us to only return rows where the users are present
    # significantly faster than returning everything for the day
    user_where_clauses =
      1..Enum.count(user_ids)
      |> Enum.map_join("\n OR ", fn idx ->
        "logs.data -> 'client' -> 'total' @> $#{idx + 2}"
      end)

    # Main query itself
    query = """
      SELECT
        logs.timestamp,
        logs.data -> 'client'
      FROM teiserver_server_minute_logs logs
      WHERE logs.timestamp >= $1
        AND logs.timestamp < $2
        AND (
          #{user_where_clauses}
        )
      ORDER BY logs.timestamp ASC
      LIMIT 1440
    """

    start_time = DateTime.new!(params["date"], ~T[00:00:00], "Etc/UTC")

    end_date = Date.add(params["date"], 1)
    end_time = DateTime.new!(end_date, ~T[00:00:00], "Etc/UTC")

    {:ok, %{rows: rows}} =
      SQL.query(Repo, query, [start_time, end_time] ++ user_ids)

    # Generate a map of the data against the time it refers to
    data =
      rows
      |> Enum.map(fn [timestamp, cdata] ->
        userdata =
          user_ids
          |> Enum.with_index()
          |> Enum.map(fn {user_id, idx} ->
            idx_mod = idx * 0.1

            status =
              cond do
                cdata == nil -> @offline
                Enum.member?(cdata["menu"], user_id) -> @menu - idx_mod
                Enum.member?(cdata["lobby"], user_id) -> @lobby - idx_mod
                Enum.member?(cdata["spectator"], user_id) -> @spectator - idx_mod
                Enum.member?(cdata["player"], user_id) -> @player - idx_mod
                true -> @offline
              end

            status
          end)

        time =
          timestamp
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.to_time()

        {
          time,
          userdata
        }
      end)

    # If we need to include nil then we have to tweak the data slightly
    if params["include_nil"] do
      data = Map.new(data)

      # Now generate a list of rows for empty data against timestamps when
      # none of the users were logged in
      blank_data = user_ids |> Enum.map(fn _id -> 0 end)

      1..1440
      |> Enum.map(fn minute ->
        time = Time.new!(0, 0, 0) |> Time.add(minute, :minute)

        userdata = Map.get(data, time, blank_data)

        {
          time,
          userdata
        }
      end)
    else
      data
    end
  end

  # Go through the users selected as part of the params, convert them to integers
  # and reject any non-user_ids
  defp get_user_ids(params) do
    1..@user_count_max
    |> Enum.map(fn i ->
      StringHelper.maybe_to_integer(params["user#{i}"])
    end)
    |> Enum.reject(&(&1 == nil))
  end
end
