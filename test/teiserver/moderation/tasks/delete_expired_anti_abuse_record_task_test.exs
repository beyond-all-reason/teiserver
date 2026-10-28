defmodule Teiserver.Moderation.DeleteExpiredAntiAbuseRecordTaskTest do
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.Coordinator.CoordinatorServer
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Moderation.AntiAbuseRecordQueries
  alias Teiserver.Moderation.DeleteExpiredAARTask
  alias Teiserver.ModerationFixtures

  use Teiserver.DataCase, async: false

  setup do
    CoordinatorServer.make_and_cache_coordinator_account()
    scope = Account.system_scope()
    {:ok, %{scope: scope}}
  end

  describe "DeleteExpiredAntiAbuseRecordTask" do
    test "no records" do
      :ok = DeleteExpiredAARTask.perform(%{})

      count =
        AntiAbuseRecordQueries.anti_abuse_records()
        |> QueryHelpers.count()

      assert count == 0
    end

    test "no expired records", %{scope: scope} do
      record = ModerationFixtures.anti_abuse_record_fixture(scope)

      :ok = DeleteExpiredAARTask.perform(%{})

      aar_count =
        AntiAbuseRecordQueries.anti_abuse_records()
        |> QueryHelpers.count()

      assert aar_count == 1

      assert %User{} = Account.get_user_by_id(record.user_id)
    end

    test "expired record", %{scope: scope} do
      record =
        ModerationFixtures.anti_abuse_record_fixture(%{
          scope: scope,
          expires_at: DateTime.utc_now() |> DateTime.shift(day: -1)
        })

      :ok = DeleteExpiredAARTask.perform(%{})

      aar_count =
        AntiAbuseRecordQueries.anti_abuse_records()
        |> QueryHelpers.count()

      assert aar_count == 0

      assert Account.get_user_by_id(record.user_id) == nil
    end
  end
end
