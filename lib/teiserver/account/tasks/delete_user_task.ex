defmodule Teiserver.Admin.DeleteUserTask do
  @moduledoc false
  alias Teiserver.Repo
  alias Teiserver.{Account, User}

  @doc """
  Expects a list of user ids, returns the results of the query
  """
  @spec delete_users([non_neg_integer()]) :: :ok
  def delete_users(id_list) do
    id_list
    |> Enum.each(&Account.decache_user/1)

    # Clan memberships
    query = "DELETE FROM teiserver_clan_memberships WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Accolades
    query =
      "DELETE FROM teiserver_account_accolades WHERE recipient_id = ANY($1) OR giver_id = ANY($1)"

    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Relationships
    query = "DELETE FROM account_relationships WHERE to_user_id = ANY($1) OR from_user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Events/Properties
    query = "DELETE FROM teiserver_telemetry_client_events WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    query = "DELETE FROM teiserver_telemetry_client_properties WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    query = "DELETE FROM teiserver_telemetry_server_events WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    query = "DELETE FROM teiserver_telemetry_match_events WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Stats
    query = "DELETE FROM teiserver_account_user_stats WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Chat
    query = "DELETE FROM teiserver_lobby_messages WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    query = "DELETE FROM teiserver_room_messages WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Match memberships (how are they a member of a match if unverified?
    query = "DELETE FROM teiserver_battle_match_memberships WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Ratings too
    query = "DELETE FROM teiserver_account_ratings WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    query = "DELETE FROM teiserver_game_rating_logs WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Smurf keys
    query = "DELETE FROM teiserver_account_smurf_keys WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Delete our cache of them
    id_list
    |> Enum.each(fn userid -> User.decache_user(userid) end)

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
