defmodule Teiserver.Moderation.ReportGroupQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Moderation.ReportGroup

  # Queries
  @spec query_report_groups(list) :: Ecto.Query.t()
  def query_report_groups(args) do
    query = from(report_groups in ReportGroup)

    query
    |> do_where(id: args[:id])
    |> do_where(args[:where])
    |> do_preload(args[:preload])
    |> do_order_by(args[:order_by])
    |> query_select(args[:select])
    |> limit_query(args[:limit])
    |> offset_query(args[:offset])
  end

  @spec do_where(Ecto.Query.t(), list | map | nil) :: Ecto.Query.t()
  defp do_where(query, nil), do: query

  defp do_where(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _where(query_acc, key, value)
    end)
  end

  @spec _where(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  defp _where(query, _, ""), do: query
  defp _where(query, _, nil), do: query

  defp _where(query, :id, id) do
    from report_groups in query,
      where: report_groups.id == ^id
  end

  defp _where(query, :id_in, id_list) do
    from report_groups in query,
      where: report_groups.id in ^id_list
  end

  defp _where(query, :target_id, target_id) do
    from report_groups in query,
      where: report_groups.target_id == ^target_id
  end

  defp _where(query, :match_id, false) do
    from report_groups in query,
      where: is_nil(report_groups.match_id)
  end

  defp _where(query, :match_id, match_id) do
    from report_groups in query,
      where: report_groups.match_id == ^match_id
  end

  defp _where(query, :closed, closed) do
    from report_groups in query,
      where: report_groups.closed == ^closed
  end

  defp _where(query, :actioned, true) do
    from report_groups in query,
      where: report_groups.action_count > 0
  end

  defp _where(query, :actioned, false) do
    from report_groups in query,
      where: report_groups.action_count == 0
  end

  defp _where(query, :actioned, _), do: query

  defp _where(query, :inserted_after, datetime) do
    from report_groups in query,
      where: report_groups.inserted_at >= ^datetime
  end

  defp _where(query, :has_reports_of_kind, kind) do
    from report_groups in query,
      join: reports in assoc(report_groups, :reports),
      where: fragment("? ~* ?", reports.type, ^kind)
  end

  @spec do_order_by(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  defp do_order_by(query, nil), do: query

  defp do_order_by(query, params) when is_list(params) do
    params
    |> Enum.reduce(query, fn key, query_acc ->
      _order_by(query_acc, key)
    end)
  end

  defp do_order_by(query, params), do: do_order_by(query, [params])

  defp _order_by(query, nil), do: query

  defp _order_by(query, "Newest first") do
    from report_groups in query,
      order_by: [desc: report_groups.updated_at]
  end

  defp _order_by(query, "Oldest first") do
    from report_groups in query,
      order_by: [asc: report_groups.updated_at]
  end

  @spec do_preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :target) do
    from report_groups in query,
      join: targets in assoc(report_groups, :target),
      preload: [target: targets]
  end

  defp _preload(query, :actions) do
    from report_groups in query,
      left_join: actions in assoc(report_groups, :actions),
      preload: [actions: actions]
  end

  defp _preload(query, :reports) do
    from report_groups in query,
      left_join: reports in assoc(report_groups, :reports),
      preload: [reports: reports]

    # TODO add reporters here
  end

  # defp _preload(query, :users) do
  #   from report_groups in query,
  #     join: tos in assoc(report_groups, :to),
  #     preload: [to: tos],
  #     join: froms in assoc(report_groups, :from),
  #     preload: [from: froms]
  # end
end
