defmodule Teiserver.Chat.BattleMessageQueries do
  @moduledoc false

  alias Ecto.Query
  alias Teiserver.Account.User
  alias Teiserver.Battle.Match
  alias Teiserver.Chat.BattleMessage
  alias Teiserver.Chat.TermSearch

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec battle_messages() :: t()
  def battle_messages do
    from(battle_messages in BattleMessage, as: :battle_messages)
  end

  @spec where_match_id(t(), nil | Match.id()) :: t()
  def where_match_id(query, nil), do: query

  def where_match_id(query, match_id) do
    from battle_messages in query,
      where: battle_messages.match_id == ^match_id
  end

  @spec where_from_id(t(), nil | User.id()) :: t()
  def where_from_id(query, nil), do: query

  def where_from_id(query, from_id) do
    from battle_messages in query,
      where: battle_messages.from_id == ^from_id
  end

  @spec where_to_id(t(), nil | User.id()) :: t()
  def where_to_id(query, nil), do: query

  def where_to_id(query, to_id) do
    from battle_messages in query,
      where: battle_messages.to_id == ^to_id
  end

  @spec where_destination(t(), nil | String.t()) :: t()
  def where_destination(query, nil), do: query

  def where_destination(query, destination) do
    from battle_messages in query,
      where: battle_messages.destination == ^destination
  end

  @spec where_inserted_after(t(), nil | DateTime.t()) :: t()
  def where_inserted_after(query, nil), do: query

  def where_inserted_after(query, timestamp) do
    from battle_messages in query,
      where: battle_messages.inserted_at >= ^timestamp
  end

  @spec where_inserted_before(t(), nil | DateTime.t()) :: t()
  def where_inserted_before(query, nil), do: query

  def where_inserted_before(query, timestamp) do
    from battle_messages in query,
      where: battle_messages.inserted_at < ^timestamp
  end

  @spec where_term(t(), nil | String.t(), keyword()) :: t()
  def where_term(query, term, opts \\ []), do: TermSearch.content_filter(query, term, opts)

  @spec load_from(t()) :: t()
  def load_from(query) do
    from battle_messages in query,
      left_join: from in User,
      as: :from,
      on: battle_messages.from_id == from.id,
      preload: [from: from]
  end

  @spec load_to(t()) :: t()
  def load_to(query) do
    from battle_messages in query,
      left_join: to in User,
      as: :to,
      on: battle_messages.to_id == to.id,
      preload: [to: to]
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(battle_messages in query,
        order_by: [asc: battle_messages.inserted_at, asc: battle_messages.id]
      )
    else
      from(battle_messages in query,
        order_by: [desc: battle_messages.inserted_at, desc: battle_messages.id]
      )
    end
  end

  @spec order_by_from_string(t(), nil | String.t()) :: t()
  def order_by_from_string(query, nil), do: query
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
end
