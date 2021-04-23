defmodule Central.Account.ReportLib do
  use CentralWeb, :library
  alias Central.Account.Report

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-flag"
  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:warning)

  @spec make_favourite(Report.t()) :: Map.t()
  def make_favourite(report) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),
      item_id: report.id,
      item_type: "central_account_report",
      item_colour: colours() |> elem(0),
      item_icon: Central.Account.ReportLib.icon(),
      item_label: "#{report.reporter.name} -> #{report.target.name}",
      url: "/account/reports/#{report.id}"
    }
  end

  @spec response_actions() :: [String.t()]
  def response_actions() do
    [
      "Ignore report",
      "Mute",
      "Ban"
    ]
  end

  @spec action_icon(String.t() | nil) :: String.t()
  def action_icon(nil), do: ""
  def action_icon("Ignore report"), do: "fas fa-check-circle"
  def action_icon("Mute"), do: "fas fa-microphone-slash"
  def action_icon("Ban"), do: "fas fa-ban"

  def perform_action(_report, "Ignore report", _data) do
    {:ok, nil}
  end

  def perform_action(_report, _, "never"), do: {:ok, nil}
  def perform_action(_report, _, "Never"), do: {:ok, nil}

  def perform_action(_report, "Mute", data) do
    case HumanTime.relative(data) do
      {:ok, muted_until} ->
        {:ok, muted_until}

      err ->
        err
    end
  end

  def perform_action(_report, "Ban", data) do
    case HumanTime.relative(data) do
      {:ok, banned_until} ->
        {:ok, banned_until}

      err ->
        err
    end
  end

  # Queries
  @spec query_reports() :: Ecto.Query.t()
  def query_reports do
    from(reports in Report)
  end

  @spec search(Ecto.Query.t(), Map.t() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from reports in query,
      where: reports.id == ^id
  end

  def _search(query, :id_list, id_list) do
    from reports in query,
      where: reports.id in ^id_list
  end

  def _search(query, :user_id, user_id) do
    from reports in query,
      where:
        reports.reporter_id == ^user_id or
          reports.target_id == ^user_id or
          reports.responder_id == ^user_id
  end

  def _search(query, :filter, "all"), do: query

  def _search(query, :filter, "open") do
    from reports in query,
      where: is_nil(reports.responder_id)
  end

  def _search(query, :filter, "closed") do
    from reports in query,
      where: not is_nil(reports.responder_id)
  end

  def _search(query, :filter, {"all", _}), do: query

  def _search(query, :filter, {"target", user_id}) do
    from reports in query,
      where: reports.target_id == ^user_id
  end

  def _search(query, :filter, {"reporter", user_id}) do
    from reports in query,
      where: reports.reporter_id == ^user_id
  end

  def _search(query, :filter, {"responder", user_id}) do
    from reports in query,
      where: reports.responder_id == ^user_id
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from reports in query,
      order_by: [desc: reports.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from reports in query,
      order_by: [asc: reports.inserted_at]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :reporter in preloads, do: _preload_reporter(query), else: query
    query = if :target in preloads, do: _preload_target(query), else: query
    query = if :responder in preloads, do: _preload_responder(query), else: query
    query
  end

  def _preload_reporter(query) do
    from reports in query,
      left_join: reporters in assoc(reports, :reporter),
      preload: [reporter: reporters]
  end

  def _preload_target(query) do
    from reports in query,
      left_join: targets in assoc(reports, :target),
      preload: [target: targets]
  end

  def _preload_responder(query) do
    from reports in query,
      left_join: responders in assoc(reports, :responder),
      preload: [responder: responders]
  end
end
