defmodule Teiserver.Account.MergeAccountsTask do
  alias Teiserver.{User}
  alias Central.Repo
  require Logger

  def perform(deleting_id, keeping_id) do
    query = "UPDATE teiserver_telemetry_client_events SET user_id = #{keeping_id} WHERE user_id = #{deleting_id}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    query = "UPDATE teiserver_telemetry_client_properties SET user_id = #{keeping_id} WHERE user_id = #{deleting_id}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    query = "UPDATE teiserver_account_user_stats SET user_id = #{keeping_id} WHERE user_id = #{deleting_id}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    query = "UPDATE teiserver_battle_match_memberships SET user_id = #{keeping_id} WHERE user_id = #{deleting_id}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    query = "UPDATE teiserver_lobby_messages SET user_id = #{keeping_id} WHERE user_id = #{deleting_id}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    query = "UPDATE teiserver_room_messages SET user_id = #{keeping_id} WHERE user_id = #{deleting_id}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    # Reports
    query = "UPDATE account_reports SET reporter_id = #{keeping_id} WHERE reporter_id = #{deleting_id}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    query = "UPDATE account_reports SET target_id = #{keeping_id} WHERE target_id = #{deleting_id}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    Central.Admin.DeleteUserTask.delete_users([deleting_id])
    User.delete_user(deleting_id)
  end
end


# Teiserver.Account.MergeAccountsTask.perform(17925, 9265)
# Teiserver.Account.MergeAccountsTask.perform(9756, 9265)
