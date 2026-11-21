defmodule Teiserver.Moderation.LobbyLogQueries do
  @moduledoc false

  alias Ecto.Query
  alias Ecto.UUID
  alias Teiserver.Account.User
  alias Teiserver.Moderation.LobbyLog

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec lobby_logs() :: t()
  def lobby_logs do
    from(lobby_logs in LobbyLog, as: :lobby_logs)
  end

  @spec where_lobby_id(t(), nil | UUID.t()) :: t()
  def where_lobby_id(query, nil), do: query

  def where_lobby_id(query, lobby_id) do
    from lobby_logs in query,
      where: lobby_logs.lobby_id == ^lobby_id
  end

  @spec where_user_id(t(), nil | User.id()) :: t()
  def where_user_id(query, nil), do: query

  def where_user_id(query, user_id) do
    from lobby_logs in query,
      where: lobby_logs.user_id == ^user_id
  end

  @spec where_target_id(t(), nil | User.id()) :: t()
  def where_target_id(query, nil), do: query

  def where_target_id(query, target_id) do
    from lobby_logs in query,
      where: lobby_logs.target_id == ^target_id
  end

  @spec where_event_type(t(), nil | String.t()) :: t()
  def where_event_type(query, nil), do: query
  def where_event_type(query, "Any"), do: query

  def where_event_type(query, event_type) do
    from lobby_logs in query,
      where: lobby_logs.event_type == ^event_type
  end

  @spec load_user(t()) :: t()
  def load_user(query) do
    from lobby_logs in query,
      left_join: users in User,
      as: :users,
      on: lobby_logs.user_id == users.id,
      preload: [user: users]
  end

  @spec load_target(t()) :: t()
  def load_target(query) do
    from lobby_logs in query,
      left_join: targets in User,
      as: :targets,
      on: lobby_logs.target_id == targets.id,
      preload: [target: targets]
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(lobby_logs in query, order_by: [asc: lobby_logs.inserted_at])
    else
      from(lobby_logs in query, order_by: [desc: lobby_logs.inserted_at])
    end
  end

  @spec order_by_from_string(t(), String.t()) :: t()
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
end
