defmodule Central.Logging.LoggingTestLib do
  @moduledoc false
  use CentralWeb, :library

  alias Central.Logging.PageViewLog
  alias Central.Logging.PageViewLogLib
  alias Central.Logging.AuditLog

  alias Central.Logging.AggregateViewLog
  alias Central.Logging.AggregateViewLogLib

  # def get_audit_log(conn, action) do
  #   Logging.list_audit_logs(search: [
  #     user_id: conn.assigns[:current_user].id,
  #     action: action
  #   ])
  # end

  def new_page_view_log(user, data \\ %{}) do
    PageViewLog.changeset(%PageViewLog{}, %{
      section: data["section"] || "section",
      path: data["path"] || "section/sub/page",
      method: data["method"] || "400",
      ip: data["ip"] || "127.0.0.1",
      load_time: data["load_time"] || 105,
      user_id: user.id,
      status: data["status"] || 200
    })
    |> Repo.insert!()
  end

  def fake_audit_log(user) do
    AuditLog.changeset(%AuditLog{}, %{
      action: "Fake log",
      ip: "127.0.0.1",
      details: %{},
      user_id: user.id
    })
    |> Repo.insert!()
  end

  def fake_aggregate_log(date) do
    AggregateViewLog.changeset(%AggregateViewLog{}, %{
      "date" => date,
      "total_views" => 103,
      "total_uniques" => 13,
      "average_load_time" => 5678,
      "guest_view_count" => 13,
      "guest_unique_ip_count" => 4,
      "percentile_load_time_95" => 12_445,
      "percentile_load_time_99" => 14_788,
      "max_load_time" => 19_871,
      "hourly_views" => 1..24 |> Enum.map(&(&1 * 4)),
      "hourly_uniques" => 1..24 |> Enum.map(&(&1 * 6)),
      "hourly_average_load_times" => 1..24 |> Enum.map(&(&1 * 1987)),
      "user_data" => %{},
      "section_data" => %{}
    })
    |> Repo.insert!()
  end

  def seed(existing) do
    users = existing[:users]

    page_view_logs =
      users
      |> Enum.map(fn u ->
        1..6
        |> Enum.map(fn _ ->
          new_page_view_log(u)
        end)
      end)

    audit_logs =
      users
      |> Enum.map(fn u ->
        1..6
        |> Enum.map(fn _ ->
          fake_audit_log(u)
        end)
      end)

    aggregate_logs =
      4..14
      |> Enum.map(fn i ->
        Timex.beginning_of_day(Timex.now())
        |> Timex.shift(days: -i)
        |> fake_aggregate_log()
      end)

    existing ++
      [
        page_view_logs: page_view_logs,
        audit_logs: audit_logs,
        aggregate_logs: aggregate_logs
      ]
  end

  @spec logging_setup(List.t()) :: {:ok, List.t()}
  @spec logging_setup(List.t(), List.t()) :: {:ok, List.t()}
  def logging_setup(existing, flags \\ []) do
    {:ok, existing} = existing

    child_user = existing[:child_user]

    aggregate_logs =
      if flags[:aggregate_logs] do
        AggregateViewLogLib.get_logs()
        |> AggregateViewLogLib.order("Oldest first")
        |> Repo.all()
      end

    page_view_logs =
      if flags[:page_view_logs] do
        PageViewLogLib.get_page_view_logs()
        |> PageViewLogLib.search(user_id: child_user.id)
        |> Repo.all()
      end

    {:ok,
     existing ++
       [
         aggregate_logs: aggregate_logs,
         page_view_logs: page_view_logs
       ]}
  end
end
