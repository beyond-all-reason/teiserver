defmodule Teiserver.Moderation.ReportLib do
  @moduledoc false
  use CentralWeb, :library
  alias Teiserver.Moderation.Report

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-flag"

  @spec colour :: atom
  def colour, do: :warning

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(report) do
    %{
      type_colour: colour(),
      type_icon: icon(),

      item_id: report.id,
      item_type: "teiserver_moderation_report",
      item_colour: colour(),
      item_icon: icon(),
      item_label: "#{report.reporter.name} -> #{report.target.name}",

      url: "/teiserver/moderation/reports/#{report.id}"
    }
  end

  # Queries
  @spec query_reports() :: Ecto.Query.t
  def query_reports do
    from reports in Report
  end

  @spec search(Ecto.Query.t, Map.t | nil) :: Ecto.Query.t
  def search(query, nil), do: query
  def search(query, params) do
    params
    |> Enum.reduce(query, fn ({key, value}, query_acc) ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t, Atom.t(), any()) :: Ecto.Query.t
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from reports in query,
      where: reports.id == ^id
  end

  def _search(query, :id_in, id_list) do
    from reports in query,
      where: reports.id in ^id_list
  end

  def _search(query, :target_id, target_id) do
    from reports in query,
      where: reports.target_id == ^target_id
  end

  def _search(query, :target_id_in, id_list) do
    from reports in query,
      where: reports.target_id in ^id_list
  end

  def _search(query, :result_id, result_id) do
    from reports in query,
      where: reports.result_id == ^result_id
  end

  def _search(query, :result_id_in, id_list) do
    from reports in query,
      where: reports.result_id in ^id_list
  end

  def _search(query, :reporter_id, reporter_id) do
    from reports in query,
      where: reports.reporter_id == ^reporter_id
  end

  def _search(query, :reporter_id_in, id_list) do
    from reports in query,
      where: reports.reporter_id in ^id_list
  end

  def _search(query, :no_result, true) do
    from reports in query,
      where: is_nil(reports.result_id)
  end

  def _search(query, :no_result, false) do
    from reports in query,
      where: not is_nil(reports.result_id)
  end

  def _search(query, :inserted_after, datetime) do
    from reports in query,
      where: reports.inserted_at > ^datetime
  end

  def _search(query, :inserted_before, datetime) do
    from reports in query,
      where: reports.inserted_at < ^datetime
  end

  def _search(query, :id_list, id_list) do
    from reports in query,
      where: reports.id in ^id_list
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Newest first") do
    from reports in query,
      order_by: [desc: reports.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from reports in query,
      order_by: [asc: reports.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, preloads) do
    query = if :reporter in preloads, do: _preload_reporter(query), else: query
    query = if :target in preloads, do: _preload_target(query), else: query
    query = if :action in preloads, do: _preload_action(query), else: query
    query = if :match in preloads, do: _preload_match(query), else: query
    query
  end

  @spec _preload_reporter(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_reporter(query) do
    from reports in query,
      left_join: reporters in assoc(reports, :reporter),
      preload: [reporter: reporters]
  end

  @spec _preload_target(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_target(query) do
    from reports in query,
      left_join: targets in assoc(reports, :target),
      preload: [target: targets]
  end

  @spec _preload_action(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_action(query) do
    from reports in query,
      left_join: actions in assoc(reports, :action),
      preload: [action: actions]
  end

  @spec _preload_match(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_match(query) do
    from reports in query,
      left_join: matchs in assoc(reports, :match),
      preload: [match: matchs]
  end
end
