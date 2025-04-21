defmodule Teiserver.Microblog.UploadQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Microblog.Upload
  alias Teiserver.Helper.QueryHelpers

  # Queries
  @spec query_uploads(list) :: Ecto.Query.t()
  def query_uploads(args) do
    query = from(uploads in Upload)

    query
    |> do_where(id: args[:id])
    |> do_where(args[:where])
    |> do_preload(args[:preload])
    |> do_order_by(args[:order_by])
    |> query_select(args[:select])
    |> QueryHelpers.limit_query(args[:limit])
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
    from uploads in query,
      where: uploads.id == ^id
  end

  defp _where(query, :uploader_id, uploader_id) do
    from uploads in query,
      where: uploads.uploader_id in ^List.wrap(uploader_id)
  end

  @spec do_order_by(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  defp do_order_by(query, nil), do: query

  defp do_order_by(query, params) when is_list(params) do
    params
    |> Enum.reduce(query, fn key, query_acc ->
      _order_by(query_acc, key)
    end)
  end

  defp do_order_by(query, params) when is_bitstring(params), do: do_order_by(query, [params])

  defp _order_by(query, nil), do: query

  defp _order_by(query, "Newest first") do
    from uploads in query,
      order_by: [desc: uploads.inserted_at]
  end

  defp _order_by(query, "Oldest first") do
    from uploads in query,
      order_by: [asc: uploads.inserted_at]
  end

  @spec do_preload(Ecto.Query.t(), List | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :uploader) do
    from uploads in query,
      left_join: uploaders in assoc(uploads, :uploader),
      preload: [uploader: uploaders]
  end
end
