defmodule Teiserver.Admin.DeleteUserTask do
  @moduledoc false
  alias Ecto.Adapters.SQL
  alias Teiserver.Account
  alias Teiserver.CacheUser
  alias Teiserver.Repo

  @doc """
  Expects a list of user ids, hard deletes the user and most related
  data. Anything not deleted is nulled or swapped to reference the system
  user. This function _cannot_ be undone without restoring a backup.
  """
  @spec delete_users([non_neg_integer()]) :: :ok
  def delete_users(id_list) do
    id_list
    |> Enum.each(&Account.decache_user/1)

    system_user_id = Account.system_user().id

    [
      # Accolades
      "DELETE FROM teiserver_account_accolades WHERE recipient_id = ANY($1) OR giver_id = ANY($1)",

      # Relationships
      "DELETE FROM account_relationships WHERE to_user_id = ANY($1) OR from_user_id = ANY($1)",
      "DELETE FROM account_friend_requests WHERE to_user_id = ANY($1) OR from_user_id = ANY($1)",
      "DELETE FROM account_friends WHERE user1_id = ANY($1) OR user2_id = ANY($1)",
      "UPDATE account_users SET smurf_of_id = NULL WHERE smurf_of_id = ANY($1)",

      # Telemetry
      "DELETE FROM telemetry_complex_client_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_simple_client_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_complex_match_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_simple_match_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_complex_lobby_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_simple_lobby_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_complex_server_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_simple_server_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_user_properties WHERE user_id = ANY($1)",

      # User table extensions/stats
      "DELETE FROM teiserver_account_user_stats WHERE user_id = ANY($1)",
      "DELETE FROM teiserver_account_smurf_keys WHERE user_id = ANY($1)",
      "DELETE FROM account_codes WHERE user_id = ANY($1)",
      "DELETE FROM config_user WHERE user_id = ANY($1)",

      # Logs
      "DELETE FROM page_view_logs WHERE user_id = ANY($1)",
      "DELETE FROM audit_logs WHERE user_id = ANY($1)",

      # Chat
      "DELETE FROM teiserver_lobby_messages WHERE user_id = ANY($1)",
      "DELETE FROM teiserver_room_messages WHERE user_id = ANY($1)",
      "DELETE FROM direct_messages WHERE from_id = ANY($1) OR to_id = ANY($1)",

      # Match stuff
      "DELETE FROM teiserver_battle_match_memberships WHERE user_id = ANY($1)",
      "DELETE FROM teiserver_account_ratings WHERE user_id = ANY($1)",
      "DELETE FROM teiserver_game_rating_logs WHERE user_id = ANY($1)",

      # Moderation
      "DELETE FROM moderation_reports WHERE reporter_id = ANY($1) OR target_id = ANY($1)",
      "DELETE FROM moderation_actions WHERE target_id = ANY($1)",
      "DELETE FROM moderation_bans WHERE source_id = ANY($1)",
      "UPDATE moderation_bans SET added_by_id = #{system_user_id} WHERE added_by_id = ANY($1)",

      # User prefs
      "DELETE FROM microblog_user_preferences WHERE user_id = ANY($1)"
    ]
    |> Enum.each(fn query ->
      SQL.query!(Repo, query, [id_list])
    end)

    # And now the users
    query = "DELETE FROM account_users WHERE id = ANY($1)"
    SQL.query!(Repo, query, [id_list])

    # Delete our cache of them
    id_list
    |> Enum.each(fn userid -> CacheUser.decache_user(userid) end)
  end
end
