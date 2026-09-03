defmodule Teiserver.Moderation.AntiAbuseRecordQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Account.User
  alias Teiserver.Moderation.AntiAbuseRecord

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec anti_abuse_records() :: t()
  def anti_abuse_records do
    from(anti_abuse_records in AntiAbuseRecord, as: :anti_abuse_records)
  end

  @spec where_id(t(), AntiAbuseRecord.id()) :: t()
  def where_id(query, id) do
    from anti_abuse_records in query,
      where: anti_abuse_records.id == ^id
  end

  @spec where_user_id(t(), User.id()) :: t()
  def where_user_id(query, nil), do: query

  def where_user_id(query, user_id) do
    from anti_abuse_records in query,
      where: anti_abuse_records.user_id == ^user_id
  end

  @spec where_clean(t(), nil | boolean()) :: t()
  def where_clean(query, nil), do: query

  def where_clean(query, clean?) do
    from anti_abuse_records in query,
      where: anti_abuse_records.clean == ^clean?
  end

  @spec where_restored(t(), nil | boolean()) :: t()
  def where_restored(query, nil), do: query

  def where_restored(query, true) do
    from anti_abuse_records in query,
      where: not is_nil(anti_abuse_records.restored_by_id)
  end

  def where_restored(query, false) do
    from anti_abuse_records in query,
      where: is_nil(anti_abuse_records.restored_by_id)
  end

  @spec where_restored_by_id(t(), nil | boolean()) :: t()
  def where_restored_by_id(query, nil), do: query
  def where_restored_by_id(query, ""), do: query

  def where_restored_by_id(query, id) do
    from anti_abuse_records in query,
      where: anti_abuse_records.restored_by_id == ^id
  end

  @spec load_user(t()) :: t()
  def load_user(query) do
    from anti_abuse_records in query,
      left_join: users in User,
      as: :record_users,
      on: anti_abuse_records.user_id == users.id,
      preload: [user: users]
  end

  @spec load_restorer(t()) :: t()
  def load_restorer(query) do
    from anti_abuse_records in query,
      left_join: restorer_users in User,
      as: :restorer_users,
      on: anti_abuse_records.restored_by_id == restorer_users.id,
      preload: [restored_by: restorer_users]
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(anti_abuse_records in query, order_by: [asc: anti_abuse_records.inserted_at])
    else
      from(anti_abuse_records in query, order_by: [desc: anti_abuse_records.inserted_at])
    end
  end
end
