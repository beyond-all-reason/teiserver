defmodule Central.Admin.DeleteUserTask do
  @moduledoc false
  alias Central.Repo

  @doc """
  Expects a list of user ids, returns the results of the query
  """
  @spec delete_users([non_neg_integer()]) :: :ok
  def delete_users(id_list) do
    # Reports
    query = """
      DELETE FROM moderation_reports
      WHERE reporter_id = ANY($1)
      OR target_id = ANY($1)
      OR responder_id = ANY($1)
    """
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Codes
    query = "DELETE FROM account_codes WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Group memberships
    query = "DELETE FROM account_group_memberships WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Next up, configs
    query = "DELETE FROM config_user WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Notifications
    query = "DELETE FROM communication_notifications WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Page view logs
    query = "DELETE FROM page_view_logs WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Audit logs
    query = "DELETE FROM audit_logs WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # And now the users
    query = "DELETE FROM account_users WHERE id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    :ok
  end
end
