defmodule Teiserver.Account.UserNoteQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Account.User
  alias Teiserver.Account.UserNote

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec user_notes() :: t()
  def user_notes do
    from(user_notes in UserNote, as: :user_notes)
  end

  @spec where_id(t(), UserNote.id()) :: t()
  def where_id(query, id) do
    from user_notes in query,
      where: user_notes.id == ^id
  end

  @spec where_user_id(t(), User.id()) :: t()
  def where_user_id(query, nil), do: query

  def where_user_id(query, user_id) do
    from user_notes in query,
      where: user_notes.user_id == ^user_id
  end

  @spec where_creator_id(t(), User.id()) :: t()
  def where_creator_id(query, nil), do: query

  def where_creator_id(query, creator_id) do
    from user_notes in query,
      where: user_notes.creator_id == ^creator_id
  end

  @spec load_user(t()) :: t()
  def load_user(query) do
    from user_notes in query,
      left_join: users in User,
      as: :record_users,
      on: user_notes.user_id == users.id,
      preload: [user: users]
  end

  @spec load_creator(t()) :: t()
  def load_creator(query) do
    from user_notes in query,
      left_join: creator_users in User,
      as: :creator_users,
      on: user_notes.creator_id == creator_users.id,
      preload: [creator: creator_users]
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(user_notes in query, order_by: [asc: user_notes.inserted_at])
    else
      from(user_notes in query, order_by: [desc: user_notes.inserted_at])
    end
  end

  @spec order_by_from_string(t(), String.t()) :: t()
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
end
