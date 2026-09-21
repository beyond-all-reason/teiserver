defmodule Teiserver.Moderation.ActionQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Account.User
  alias Teiserver.Moderation.Action

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec actions() :: t()
  def actions do
    from(actions in Action, as: :actions)
  end

  @spec where_id(t(), Action.id()) :: t()
  def where_id(query, id) do
    from actions in query,
      where: actions.id == ^id
  end

  @spec where_target_id(t(), User.id()) :: t()
  def where_target_id(query, nil), do: query

  def where_target_id(query, target_id) do
    from actions in query,
      where: actions.target_id == ^target_id
  end

  # Expiry
  @spec where_expired(t()) :: t()
  def where_expired(query, now \\ nil) do
    now = now || DateTime.utc_now()

    from actions in query,
      where: actions.expires < ^now
  end

  @spec where_not_expired(t()) :: t()
  def where_not_expired(query, now \\ nil) do
    now = now || DateTime.utc_now()

    from actions in query,
      where: actions.expires > ^now
  end

  @spec load_target(t()) :: t()
  def load_target(query) do
    from actions in query,
      left_join: targets in User,
      as: :record_targets,
      on: actions.target_id == targets.id,
      preload: [target: targets]
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(actions in query, order_by: [asc: actions.inserted_at])
    else
      from(actions in query, order_by: [desc: actions.inserted_at])
    end
  end

  @spec order_by_expires(t(), :asc | :desc) :: t()
  def order_by_expires(query, direction \\ :asc) do
    if direction == :asc do
      from(actions in query, order_by: [asc: actions.expires])
    else
      from(actions in query, order_by: [desc: actions.expires])
    end
  end

  @spec order_by_from_string(t(), String.t()) :: t()
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
  def order_by_from_string(query, "Expires earliest"), do: order_by_expires(query, :asc)
  def order_by_from_string(query, "Expires latest"), do: order_by_expires(query, :desc)
end
