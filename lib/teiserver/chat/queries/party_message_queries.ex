defmodule Teiserver.Chat.PartyMessageQueries do
  @moduledoc false

  alias Ecto.Query
  alias Ecto.UUID
  alias Teiserver.Account.User
  alias Teiserver.Chat.PartyMessage
  alias Teiserver.Chat.TermSearch

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec party_messages() :: t()
  def party_messages do
    from(party_messages in PartyMessage, as: :party_messages)
  end

  @spec where_party_id(t(), nil | UUID.t()) :: t()
  def where_party_id(query, nil), do: query

  def where_party_id(query, party_id) do
    from party_messages in query,
      where: party_messages.party_id == ^party_id
  end

  @spec where_user_id(t(), nil | User.id()) :: t()
  def where_user_id(query, nil), do: query

  def where_user_id(query, user_id) do
    from party_messages in query,
      where: party_messages.user_id == ^user_id
  end

  @spec where_user_id_in(t(), nil | [User.id()]) :: t()
  def where_user_id_in(query, nil), do: query
  def where_user_id_in(query, []), do: query

  def where_user_id_in(query, user_ids) do
    from party_messages in query,
      where: party_messages.user_id in ^user_ids
  end

  @spec where_user_id_not_in(t(), nil | [User.id()]) :: t()
  def where_user_id_not_in(query, nil), do: query
  def where_user_id_not_in(query, []), do: query

  def where_user_id_not_in(query, user_ids) do
    from party_messages in query,
      where: party_messages.user_id not in ^user_ids
  end

  @spec where_inserted_after(t(), nil | DateTime.t()) :: t()
  def where_inserted_after(query, nil), do: query

  def where_inserted_after(query, timestamp) do
    from party_messages in query,
      where: party_messages.inserted_at >= ^timestamp
  end

  @spec where_inserted_before(t(), nil | DateTime.t()) :: t()
  def where_inserted_before(query, nil), do: query

  def where_inserted_before(query, timestamp) do
    from party_messages in query,
      where: party_messages.inserted_at < ^timestamp
  end

  @spec where_term(t(), nil | String.t(), keyword()) :: t()
  def where_term(query, term, opts \\ []), do: TermSearch.content_filter(query, term, opts)

  @spec load_user(t()) :: t()
  def load_user(query) do
    from party_messages in query,
      left_join: users in User,
      as: :users,
      on: party_messages.user_id == users.id,
      preload: [user: users]
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(party_messages in query,
        order_by: [asc: party_messages.inserted_at, asc: party_messages.id]
      )
    else
      from(party_messages in query,
        order_by: [desc: party_messages.inserted_at, desc: party_messages.id]
      )
    end
  end

  @spec order_by_from_string(t(), nil | String.t()) :: t()
  def order_by_from_string(query, nil), do: query
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
end
