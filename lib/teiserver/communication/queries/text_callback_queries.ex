defmodule Teiserver.Communication.TextCallbackQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Communication.TextCallback

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec text_callbacks() :: t()
  def text_callbacks do
    from(text_callbacks in TextCallback, as: :text_callbacks)
  end

  @spec where_id(t(), TextCallback.id()) :: t()
  def where_id(query, id) do
    from text_callbacks in query,
      where: text_callbacks.id == ^id
  end

  @spec where_name_like(t(), String.t()) :: t()
  def where_name_like(query, ""), do: query

  def where_name_like(query, search_term) do
    search_term = "%" <> search_term <> "%"

    from text_callbacks in query,
      where: ilike(text_callbacks.name, ^search_term)
  end

  @spec where_response_like(t(), String.t()) :: t()
  def where_response_like(query, ""), do: query

  def where_response_like(query, search_term) do
    search_term = "%" <> search_term <> "%"

    from text_callbacks in query,
      where: ilike(text_callbacks.response, ^search_term)
  end

  @spec where_category(t(), String.t()) :: t()
  def where_category(query, ""), do: query

  def where_category(query, category) do
    from text_callbacks in query,
      where: text_callbacks.category == ^category
  end

  @spec where_enabled(t(), boolean() | nil) :: t()
  def where_enabled(query, nil), do: query

  def where_enabled(query, enabled_status) do
    from text_callbacks in query,
      where: text_callbacks.enabled == ^enabled_status
  end

  @spec order_by_name(t(), :asc | :desc) :: t()
  def order_by_name(query, direction \\ :asc) do
    if direction == :asc do
      from(text_callbacks in query, order_by: [asc: text_callbacks.name])
    else
      from(text_callbacks in query, order_by: [desc: text_callbacks.name])
    end
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(text_callbacks in query, order_by: [asc: text_callbacks.inserted_at])
    else
      from(text_callbacks in query, order_by: [desc: text_callbacks.inserted_at])
    end
  end

  @spec order_by_from_string(t(), String.t()) :: t()
  def order_by_from_string(query, "Alphabetical (A-Z)"), do: order_by_name(query, :asc)
  def order_by_from_string(query, "Alphabetical (Z-A)"), do: order_by_name(query, :desc)
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
end
