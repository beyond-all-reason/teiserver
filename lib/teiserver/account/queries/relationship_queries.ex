defmodule Teiserver.Account.RelationshipQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Account.Relationship

  @spec query_relationships(list) :: Ecto.Query.t()
  def query_relationships(args) do
    query = from(relationships in Relationship)

    query
    |> do_where(from_user_id: args[:from_user_id])
    |> do_where(to_user_id: args[:to_user_id])
    |> do_where(args[:where])
    |> do_preload(args[:preload])
    |> do_order_by(args[:order_by])
    |> query_select(args[:select])
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

  defp _where(query, :from_user_id, from_id) do
    from relationships in query,
      where: relationships.from_user_id == ^from_id
  end

  defp _where(query, :to_user_id, to_id) do
    from relationships in query,
      where: relationships.to_user_id == ^to_id
  end

  defp _where(query, :from_to_id, {from_id, to_id}) do
    from relationships in query,
      where: relationships.from_user_id == ^from_id,
      where: relationships.to_user_id == ^to_id
  end

  defp _where(query, :state, state) do
    from relationships in query,
      where: relationships.state == ^state
  end

  defp _where(query, :state_in, states) do
    from relationships in query,
      where: relationships.state in ^states
  end

  defp _where(query, :ignore, value) do
    from relationships in query,
      where: relationships.ignore == ^value
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
    from relationships in query,
      order_by: [desc: relationships.updated_at]
  end

  defp _order_by(query, "Oldest first") do
    from relationships in query,
      order_by: [asc: relationships.updated_at]
  end

  @spec do_preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :from_user) do
    from relationships in query,
      join: froms in assoc(relationships, :from_user),
      preload: [from_user: froms]
  end

  defp _preload(query, :to_user) do
    from relationships in query,
      join: tos in assoc(relationships, :to_user),
      preload: [to_user: tos]
  end
end
