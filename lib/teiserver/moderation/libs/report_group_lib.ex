defmodule Teiserver.Moderation.ReportGroupLib do
  @moduledoc false
  use CentralWeb, :library
  alias Central.Helpers.QueryHelpers
  alias Teiserver.Moderation.ReportGroup

  # Queries
  @spec query_report_groups(list) :: Ecto.Query.t()
  def query_report_groups(args) do
    query = from(report_groups in ReportGroup)

    query
    |> do_where([id: args[:id]])
    |> do_where(args[:where])
    |> do_preload(args[:preload])
    |> do_order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @spec do_where(Ecto.Query.t(), list | map | nil) :: Ecto.Query.t()
  defp do_where(query, nil), do: query

  defp do_where(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _where(query_acc, key, value)
    end)
  end

  @spec _where(Ecto.Query.t(), Atom.t(), any()) :: Ecto.Query.t()
  defp _where(query, _, ""), do: query
  defp _where(query, _, nil), do: query

  defp _where(query, :id, id) do
    from report_groups in query,
      where: report_groups.id == ^id
  end

  defp _where(query, :members, {u1, u2}) when is_integer(u1) and is_integer(u2) do
    from report_groups in query,
      where: (report_groups.to_id in [^u1, ^u2] or report_groups.from_id in [^u1, ^u2])
  end

  defp _where(query, :id_in, id_list) do
    from report_groups in query,
      where: report_groups.id in ^id_list
  end

  @spec do_order_by(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  defp do_order_by(query, nil), do: query
  defp do_order_by(query, params) do
    params
    |> Enum.reduce(query, fn key, query_acc ->
      _order_by(query_acc, key)
    end)
  end

  defp _order_by(query, nil), do: query

  defp _order_by(query, "Newest first") do
    from report_groups in query,
      order_by: [desc: report_groups.updated_at]
  end

  defp _order_by(query, "Oldest first") do
    from report_groups in query,
      order_by: [asc: report_groups.updated_at]
  end

  @spec do_preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :users) do
    from report_groups in query,
      join: tos in assoc(report_groups, :to),
      preload: [to: tos],
      join: froms in assoc(report_groups, :from),
      preload: [from: froms]
  end
end
