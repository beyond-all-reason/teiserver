defmodule Teiserver.Moderation.ReportQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Moderation.Report

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec reports() :: t()
  def reports do
    from(reports in Report, as: :reports)
  end

  @spec where_id(t(), Report.id()) :: t()
  def where_id(query, id) do
    from [reports: reports] in query,
      where: reports.id == ^id
  end

  def where_inserted_after(query, nil), do: query

  def where_inserted_after(query, %Date{} = date) do
    timestamp = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    where_inserted_after(query, timestamp)
  end

  def where_inserted_after(query, %DateTime{} = timestamp) do
    from [reports: reports] in query,
      where: reports.inserted_at > ^timestamp
  end

  def where_inserted_before(query, nil), do: query

  def where_inserted_before(query, %Date{} = date) do
    timestamp = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    where_inserted_before(query, timestamp)
  end

  def where_inserted_before(query, %DateTime{} = timestamp) do
    from [reports: reports] in query,
      where: reports.inserted_at < ^timestamp
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(reports in query, order_by: [asc: reports.inserted_at, asc: reports.id])
    else
      from(reports in query, order_by: [desc: reports.inserted_at, desc: reports.id])
    end
  end

  @spec order_by_from_string(t(), String.t()) :: t()
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
end
