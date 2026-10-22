defmodule TeiserverWeb.ModerationLive.Tools.ModerationVolumeChart do
  @moduledoc false
  alias Teiserver.Helper.DateHelper
  alias Teiserver.Helper.DateHelper
  alias Teiserver.Logging.AuditLog
  alias Teiserver.Moderation.Action
  alias Teiserver.Moderation.Ban
  alias Teiserver.Moderation.Report
  alias Teiserver.Repo
  alias TeiserverWeb.ModerationLive.ToolsComponents

  use TeiserverWeb, :live_view

  import Ecto.Query, warn: false
  import Teiserver.Helper.QueryHelpers, only: [array_overlap_a_in_b: 2]

  @report_types [{:actions_type, "Actions"}, {:chat_type, "Chat"}]
  @action_restrictions [
    {:total, "Total"},
    {:warning, "Warnings"},
    {:chat, "Chat"},
    {:suspension, "Suspension"}
  ]

  @restriction_types %{
    "Warnings" => ["Warning reminder"],
    "Chat" => ["All chat"],
    "Suspension" => ["Login"]
  }

  @impl LiveView
  def mount(_params, _session, %Socket{} = socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(params, _url, %Socket{} = socket) when is_connected?(socket) do
    search = apply_default_params(params)

    socket
    |> assign(
      page_title: "Moderation volume chart",
      search: search,
      form: to_form(search),
      connected?: true,
      restriction_types: @restriction_types
    )
    |> get_data()
    |> noreply()
  end

  def handle_params(_params, _url, %Socket{} = socket) do
    socket
    |> assign(
      connected?: false,
      restriction_types: @restriction_types
    )
    |> noreply()
  end

  @impl LiveView
  def handle_event("update", params, %Socket{assigns: assigns} = socket) do
    params = convert_search_params(params)
    new_search = Map.merge(assigns.search, params)

    socket
    |> assign(search: new_search)
    |> get_data()
    |> noreply()
  end

  defp apply_default_params(params) do
    default_start_date =
      DateTime.utc_now()
      |> DateTime.to_date()
      |> Date.beginning_of_month()
      |> Date.shift(month: -1)
      |> Calendar.strftime("%Y-%m-%d")

    default_end_date =
      DateTime.utc_now()
      |> DateTime.to_date()
      |> Date.beginning_of_month()
      |> Date.shift(month: 1)
      |> Calendar.strftime("%Y-%m-%d")

    Map.merge(
      %{
        "start_date" => default_start_date,
        "end_date" => default_end_date
      },
      params
    )
    |> convert_search_params()
  end

  defp convert_search_params(params) do
    changed_params =
      %{
        "start_date" => DateHelper.parse_ymd(params["start_date"]),
        "end_date" => DateHelper.parse_ymd(params["end_date"])
      }
      |> Map.filter(fn {_key, v} -> not is_nil(v) end)

    Map.merge(params, changed_params)
  end

  defp get_data(%Socket{assigns: %{search: search}} = socket) do
    axis_dates =
      DateHelper.make_date_series(search["start_date"], search["end_date"])
      |> Enum.map(&Calendar.strftime(&1, "%Y-%m-%d"))

    %{counts: report_counts, type_data: report_type_data} = get_report_data(search)

    report_count_chart =
      LiveCharts.build(%{
        id: "total_report_counts",
        type: :line,
        series: report_counts,
        options: %{
          xaxis: %{
            categories: axis_dates
          }
        },
        adapter: LiveCharts.Adapter.ApexCharts
      })

    report_by_type_chart =
      LiveCharts.build(%{
        id: "reports_by_type_chart",
        type: :line,
        series: report_type_data,
        options: %{
          xaxis: %{
            categories: axis_dates
          }
        },
        adapter: LiveCharts.Adapter.ApexCharts
      })

    %{restrictions: restrictions} = get_action_data(search)

    restrictions_chart =
      LiveCharts.build(%{
        id: "actions_by_restriction_chart",
        type: :line,
        series: restrictions,
        options: %{
          xaxis: %{
            categories: axis_dates
          }
        },
        adapter: LiveCharts.Adapter.ApexCharts
      })

    %{ban_events: ban_events} = get_bans_data(search)

    bans_chart =
      LiveCharts.build(%{
        id: "ban_events_chart",
        type: :line,
        series: ban_events,
        options: %{
          xaxis: %{
            categories: axis_dates
          }
        },
        adapter: LiveCharts.Adapter.ApexCharts
      })

    socket
    |> assign(
      report_count_chart: report_count_chart,
      report_by_type_chart: report_by_type_chart,
      restrictions_chart: restrictions_chart,
      bans_chart: bans_chart
    )
  end

  defp get_report_data(search) do
    start_date = DateHelper.to_datetime(search["start_date"])
    end_date = DateHelper.to_datetime(search["end_date"])

    query =
      from reports in Report,
        group_by: fragment("DATE(?)", reports.inserted_at),
        select: %{
          date: fragment("DATE(?)", reports.inserted_at),
          chat_type: fragment("COUNT(*) FILTER (WHERE ? = ?)", reports.type, "chat"),
          actions_type: fragment("COUNT(*) FILTER (WHERE ? = ?)", reports.type, "actions"),
          actioned: fragment("COUNT(*) FILTER (WHERE not ? IS NULL)", reports.result_id),
          total: count(reports.id)
        },
        where: reports.inserted_at > ^start_date and reports.inserted_at < ^end_date,
        order_by: [asc: fragment("DATE(?)", reports.inserted_at)]

    report_data =
      query
      |> Repo.all()
      |> Map.new(fn row -> {row.date, row} end)

    dates =
      DateHelper.make_date_series(search["start_date"], search["end_date"])
      |> Enum.to_list()

    total_data =
      dates
      |> Enum.map(fn date ->
        report_data
        |> Map.get(date, %{})
        |> Map.get(:total, 0)
      end)

    actioned_data =
      dates
      |> Enum.map(fn date ->
        report_data
        |> Map.get(date, %{})
        |> Map.get(:actioned, 0)
      end)

    counts = [
      %{name: "Total", data: total_data},
      %{name: "Actioned", data: actioned_data}
    ]

    type_data =
      @report_types
      |> Enum.map(fn {type, label} ->
        data =
          dates
          |> Enum.map(fn date ->
            report_data
            |> Map.get(date, %{})
            |> Map.get(type, 0)
          end)

        %{name: label, data: data}
      end)

    %{counts: counts, type_data: type_data}
  end

  defp get_action_data(search) do
    start_date = DateHelper.to_datetime(search["start_date"])
    end_date = DateHelper.to_datetime(search["end_date"])

    ignored_restrictions = ["Bridging"]

    # Pull back a count by restriction and date inclusion of all actions in the date range
    # Will result in rows of:
    # %{date: date, warning: 1, chat: 3, suspension: 1, total: 5}
    query =
      from actions in Action,
        group_by: fragment("DATE(?)", actions.inserted_at),
        select: %{
          date: fragment("DATE(?)", actions.inserted_at),
          warning:
            fragment(
              "COUNT(*) FILTER (WHERE ? \\?| ?)",
              actions.restrictions,
              ^@restriction_types["Warnings"]
            ),
          chat:
            fragment(
              "COUNT(*) FILTER (WHERE ? \\?| ?)",
              actions.restrictions,
              ^@restriction_types["Chat"]
            ),
          suspension:
            fragment(
              "COUNT(*) FILTER (WHERE ? \\?| ?)",
              actions.restrictions,
              ^@restriction_types["Suspension"]
            ),
          total: count(actions.id)
        },
        where: actions.inserted_at > ^start_date and actions.inserted_at < ^end_date,
        where: not array_overlap_a_in_b(actions.restrictions, ^ignored_restrictions),
        order_by: [asc: fragment("DATE(?)", actions.inserted_at)]

    action_data =
      query
      |> Repo.all()
      |> Map.new(fn row -> {row.date, row} end)

    dates =
      DateHelper.make_date_series(search["start_date"], search["end_date"])
      |> Enum.to_list()

    restrictions_data =
      @action_restrictions
      |> Enum.map(fn {type, label} ->
        data =
          dates
          |> Enum.map(fn date ->
            action_data
            |> Map.get(date, %{})
            |> Map.get(type, 0)
          end)

        %{name: label, data: data}
      end)

    %{restrictions: restrictions_data}
  end

  def get_bans_data(search) do
    start_date = DateHelper.to_datetime(search["start_date"])
    end_date = DateHelper.to_datetime(search["end_date"])

    # Ban entity creations
    query =
      from bans in Ban,
        group_by: fragment("DATE(?)", bans.inserted_at),
        select: %{
          date: fragment("DATE(?)", bans.inserted_at),
          total: count(bans.id)
        },
        where: bans.inserted_at > ^start_date and bans.inserted_at < ^end_date,
        order_by: [asc: fragment("DATE(?)", bans.inserted_at)]

    ban_data =
      query
      |> Repo.all()
      |> Map.new(fn row -> {row.date, row} end)

    dates =
      DateHelper.make_date_series(search["start_date"], search["end_date"])
      |> Enum.to_list()

    ban_creations =
      dates
      |> Enum.map(fn date ->
        ban_data
        |> Map.get(date, %{})
        |> Map.get(:total, 0)
      end)

    # Now audit logs of Ban applications
    query =
      from audit_logs in AuditLog,
        group_by: fragment("DATE(?)", audit_logs.inserted_at),
        select: %{
          date: fragment("DATE(?)", audit_logs.inserted_at),
          total: count(audit_logs.id)
        },
        where: audit_logs.inserted_at > ^start_date and audit_logs.inserted_at < ^end_date,
        where: audit_logs.action == "Moderation:Ban enacted",
        order_by: [asc: fragment("DATE(?)", audit_logs.inserted_at)]

    log_data =
      query
      |> Repo.all()
      |> Map.new(fn row -> {row.date, row} end)

    dates =
      DateHelper.make_date_series(search["start_date"], search["end_date"])
      |> Enum.to_list()

    ban_applications =
      dates
      |> Enum.map(fn date ->
        log_data
        |> Map.get(date, %{})
        |> Map.get(:total, 0)
      end)

    ban_events = [
      %{name: "Created", data: ban_creations},
      %{name: "Applied", data: ban_applications}
    ]

    %{ban_events: ban_events}
  end
end
