defmodule Teiserver.Account.Tasks.DailyCleanupTask do
  use Oban.Worker, queue: :cleanup
  alias Teiserver.Data.Types, as: T

  alias Teiserver.Repo
  alias Teiserver.{User, Account}

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    days = Application.get_env(:central, Teiserver)[:retention][:account_unverified]

    # Find all unverified users who registered over 14 days ago
    _id_list =
      Account.list_users(
        search: [
          verified: false,
          inserted_before: Timex.shift(Timex.now(), days: -days)
        ],
        select: [:id],
        limit: :infinity
      )
      |> Enum.map(fn %{id: userid} -> userid end)

    # do_deletion(id_list)

    :ok
  end

  @spec manually_delete_user(T.userid()) :: {:ok, map()} | {:error, map()}
  def manually_delete_user(userid) do
    do_deletion([userid])
  end

  @spec do_deletion([T.userid()]) :: {:ok, map()} | {:error, map()}
  def do_deletion(id_list) do
    id_list
    |> Enum.each(&Account.decache_user/1)

    # Clan memberships
    query = "DELETE FROM teiserver_clan_memberships WHERE user_id = ANY($1)"
    Ecto.Adapters.SQL.query!(Repo, query, [id_list])

    # Accolades
    query =
      "DELETE FROM teiserver_account_accolades WHERE recipient_id = ANY($1) OR giver_id = ANY($1)"

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

    # Given there are other potential things to worry about we defer to the Central delete user task
    Central.Admin.DeleteUserTask.delete_users(id_list)
  end
end
