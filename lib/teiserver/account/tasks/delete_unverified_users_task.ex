defmodule Teiserver.Account.DeleteUnverifiedUsersTask do
  @moduledoc """
  Removes "previous_emails" from all users with them who have not
  changed their email in the last 14 days.
  """

  alias Ecto.Adapters.SQL
  alias Teiserver.Account.DeleteUnverifiedUsersTask
  alias Teiserver.Account.UserQueries
  alias Teiserver.Config
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo

  use Oban.Worker, queue: :cleanup

  @batch_size 50

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    days = Application.get_env(:teiserver, Teiserver)[:retention][:unverified_users]
    timestamp = DateTime.utc_now() |> DateTime.shift(day: -days)

    if Config.get_site_config_cache("system.DeleteUnverifiedUsersTask") do
      # Get the first @batch_size unverified users
      UserQueries.users()
      |> UserQueries.where_not_has_role("Verified")
      |> UserQueries.where_registered_before(timestamp)
      |> QueryHelpers.limit_query(@batch_size)
      |> QueryHelpers.query_select([:id])
      |> Repo.all()
      |> Enum.map(& &1.id)
      |> do_clear()
    end

    :ok
  end

  defp do_clear([]), do: :ok

  defp do_clear(user_ids) do
    [
      "DELETE FROM teiserver_account_smurf_keys WHERE user_id = ANY($1)",
      "DELETE FROM teiserver_account_user_stats WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_simple_client_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_complex_client_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_simple_server_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_complex_server_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_user_properties WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_simple_match_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_complex_match_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_simple_lobby_events WHERE user_id = ANY($1)",
      "DELETE FROM telemetry_complex_lobby_events WHERE user_id = ANY($1)",
      "DELETE FROM teiserver_game_rating_logs WHERE user_id = ANY($1)",
      "DELETE FROM teiserver_account_ratings WHERE user_id = ANY($1)",
      "DELETE FROM microblog_user_preferences WHERE user_id = ANY($1)",
      "DELETE FROM teiserver_room_messages WHERE user_id = ANY($1)",
      "DELETE FROM teiserver_account_accolades WHERE giver_id = ANY($1) OR recipient_id = ANY($1)",
      "DELETE FROM moderation_bans WHERE source_id = ANY($1) OR added_by_id = ANY($1)",
      "DELETE FROM moderation_reports WHERE reporter_id = ANY($1) OR target_id = ANY($1)",
      "DELETE FROM moderation_actions WHERE target_id = ANY($1)",
      "DELETE FROM account_relationships WHERE to_user_id = ANY($1) OR from_user_id = ANY($1)",
      "DELETE FROM direct_messages WHERE to_id = ANY($1) OR from_id = ANY($1)",
      "DELETE FROM teiserver_lobby_messages WHERE user_id = ANY($1)",
      "DELETE FROM page_view_logs WHERE user_id = ANY($1)",
      "DELETE FROM audit_logs WHERE user_id = ANY($1)",
      "DELETE FROM teiserver_battle_match_memberships WHERE user_id = ANY($1)",
      "DELETE FROM account_friends WHERE user1_id = ANY($1) OR user2_id = ANY($1)",
      "DELETE FROM account_friend_requests WHERE from_user_id = ANY($1) OR to_user_id = ANY($1)",
      "DELETE FROM config_user WHERE user_id = ANY($1)",
      "DELETE FROM account_codes WHERE user_id = ANY($1)",
      "UPDATE account_users SET smurf_of_id = NULL WHERE smurf_of_id = ANY($1)",
      "DELETE FROM account_users WHERE id = ANY($1)"
    ]
    |> Enum.each(fn query ->
      {:ok, _results} = SQL.query(Repo, query, [user_ids])
    end)

    # Create another task so we keep going until there are no more
    # unverified users left but we don't lock the users table
    # by trying to delete too many at once, if it finds no IDs then
    # it won't schedule another
    %{}
    |> DeleteUnverifiedUsersTask.new()
    |> Oban.insert()

    :ok
  end
end
