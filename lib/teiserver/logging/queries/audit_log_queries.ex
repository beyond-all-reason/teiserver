defmodule Teiserver.Logging.AuditLogQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Account.User
  alias Teiserver.Logging.AuditLog

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec audit_logs() :: t()
  def audit_logs do
    from(audit_logs in AuditLog, as: :audit_logs)
  end

  # Where id
  @spec where_id(t(), pos_integer() | String.t()) :: t()
  def where_id(query, id) do
    from audit_logs in query,
      where: audit_logs.id == ^id
  end

  # Where user_id
  @spec where_user_id(t(), [User.id()]) :: t()
  def where_user_id(query, user_id) do
    from audit_logs in query,
      where: audit_logs.user_id == ^user_id
  end

  @spec where_subject_id(t(), [User.id()]) :: t()
  def where_subject_id(query, user_id) do
    # Need to use a string for the jsonb getters
    user_id = to_string(user_id)

    from audit_logs in query,
      where:
        fragment("? ->> ? = ?", audit_logs.details, "user", ^user_id) or
          fragment("? ->> ? = ?", audit_logs.details, "user_id", ^user_id) or
          fragment("? ->> ? = ?", audit_logs.details, "target", ^user_id) or
          fragment("? ->> ? = ?", audit_logs.details, "target_id", ^user_id) or
          fragment("? ->> ? = ?", audit_logs.details, "actual_origin_id", ^user_id) or
          fragment("? ->> ? = ?", audit_logs.details, "origin_id", ^user_id) or
          fragment("? ->> ? = ?", audit_logs.details, "smurf_id", ^user_id)
  end

  # Order by
  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(audit_logs in query, order_by: [asc: audit_logs.inserted_at])
    else
      from(audit_logs in query, order_by: [desc: audit_logs.inserted_at])
    end
  end

  # Joins
  @spec load_user(t()) :: t()
  def load_user(query) do
    from audit_logs in query,
      left_join: users in User,
      as: :users,
      on: users.id == audit_logs.user_id,
      preload: [user: users]
  end
end
