defmodule Teiserver.Chat.DirectMessageQueries do
  @moduledoc false

  alias Ecto.Query
  alias Teiserver.Account.User
  alias Teiserver.Chat.DirectMessage
  alias Teiserver.Chat.TermSearch

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec direct_messages() :: t()
  def direct_messages do
    from(direct_messages in DirectMessage, as: :direct_messages)
  end

  @spec where_from_id(t(), nil | User.id()) :: t()
  def where_from_id(query, nil), do: query

  def where_from_id(query, from_id) do
    from direct_messages in query,
      where: direct_messages.from_id == ^from_id
  end

  @spec where_to_id(t(), nil | User.id()) :: t()
  def where_to_id(query, nil), do: query

  def where_to_id(query, to_id) do
    from direct_messages in query,
      where: direct_messages.to_id == ^to_id
  end

  @spec where_member_id(t(), nil | User.id()) :: t()
  def where_member_id(query, nil), do: query

  def where_member_id(query, user_id) do
    from direct_messages in query,
      where: direct_messages.from_id == ^user_id or direct_messages.to_id == ^user_id
  end

  @spec where_inserted_after(t(), nil | DateTime.t()) :: t()
  def where_inserted_after(query, nil), do: query

  def where_inserted_after(query, timestamp) do
    from direct_messages in query,
      where: direct_messages.inserted_at >= ^timestamp
  end

  @spec where_inserted_before(t(), nil | DateTime.t()) :: t()
  def where_inserted_before(query, nil), do: query

  def where_inserted_before(query, timestamp) do
    from direct_messages in query,
      where: direct_messages.inserted_at < ^timestamp
  end

  @spec where_term(t(), nil | String.t(), keyword()) :: t()
  def where_term(query, term, opts \\ []), do: TermSearch.content_filter(query, term, opts)

  @spec load_from(t()) :: t()
  def load_from(query) do
    from direct_messages in query,
      left_join: from in User,
      as: :from,
      on: direct_messages.from_id == from.id,
      preload: [from: from]
  end

  @spec load_to(t()) :: t()
  def load_to(query) do
    from direct_messages in query,
      left_join: to in User,
      as: :to,
      on: direct_messages.to_id == to.id,
      preload: [to: to]
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(direct_messages in query,
        order_by: [asc: direct_messages.inserted_at, asc: direct_messages.id]
      )
    else
      from(direct_messages in query,
        order_by: [desc: direct_messages.inserted_at, desc: direct_messages.id]
      )
    end
  end

  @spec order_by_from_string(t(), nil | String.t()) :: t()
  def order_by_from_string(query, nil), do: query
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
end
