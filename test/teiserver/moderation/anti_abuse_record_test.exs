defmodule Teiserver.Moderation.AntiAbuseRecordTest do
  # A little different from the other struct test files in that we also need to ensure access to
  # these is logged correctly

  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Moderation
  alias Teiserver.Moderation.AntiAbuseRecord

  use Teiserver.DataCase, async: true

  import Teiserver.ModerationFixtures
  import Teiserver.Logging.LoggingTestLib, only: [get_most_recent_audit_log_for_user: 1]

  setup do
    user = AccountFixtures.user_fixture()
    scope = GeneralTestLib.scope_fixture(user)

    %{user: user, scope: scope}
  end

  describe "anti_abuse_record standard utility functions" do
    test "get_anti_abuse_record/1 returns the anti_abuse_record with given id", %{
      user: user,
      scope: scope
    } do
      anti_abuse_record = anti_abuse_record_fixture(scope)
      assert Moderation.get_anti_abuse_record(anti_abuse_record.id, scope) == anti_abuse_record

      log = get_most_recent_audit_log_for_user(user.id)
      assert log.action == "Anti-abuse record access"
      assert log.details["id"] == anti_abuse_record.id
      assert log.details["action"] == "get"
    end

    test "create_anti_abuse_record/1 with valid data creates a anti_abuse_record", %{
      user: user,
      scope: scope
    } do
      valid_attrs = %{
        user_id: AccountFixtures.user_fixture().id,
        expires_at: DateTime.utc_now() |> DateTime.shift(year: 2),
        clean: true,
        hashes: %{},
        notes: "some_notes"
      }

      assert {:ok, %AntiAbuseRecord{} = anti_abuse_record} =
               Moderation.create_anti_abuse_record(valid_attrs, scope)

      assert anti_abuse_record.notes == "some_notes"
      assert anti_abuse_record.restored_at == nil

      log = get_most_recent_audit_log_for_user(user.id)
      assert log.action == "Anti-abuse record access"
      assert log.details["id"] == anti_abuse_record.id
      assert log.details["action"] == "create"
    end

    test "create_anti_abuse_record/1 with invalid data returns error changeset", %{
      user: user,
      scope: scope
    } do
      assert {:error, %Ecto.Changeset{}} =
               Moderation.create_anti_abuse_record(%{notes: nil}, scope)

      log = get_most_recent_audit_log_for_user(user.id)
      assert log.action == "Anti-abuse record access"
      assert log.details == %{"action" => "create", "changeset_action" => "insert", "id" => nil}
    end

    test "update_anti_abuse_record/2 with valid data updates the anti_abuse_record", %{
      user: user,
      scope: scope
    } do
      anti_abuse_record = anti_abuse_record_fixture(scope)

      update_attrs = %{
        notes: "some_notes"
      }

      assert {:ok, %AntiAbuseRecord{} = anti_abuse_record} =
               Moderation.update_anti_abuse_record(anti_abuse_record, update_attrs, scope)

      assert anti_abuse_record.notes == "some_notes"

      log = get_most_recent_audit_log_for_user(user.id)
      assert log.action == "Anti-abuse record access"
      assert log.details["id"] == anti_abuse_record.id
      assert log.details["action"] == "update"
    end

    test "update_anti_abuse_record/2 with invalid data returns error changeset", %{
      user: user,
      scope: scope
    } do
      anti_abuse_record = anti_abuse_record_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Moderation.update_anti_abuse_record(
                 anti_abuse_record,
                 %{user_id: nil, notes: "new notes"},
                 scope
               )

      log = get_most_recent_audit_log_for_user(user.id)
      assert log.action == "Anti-abuse record access"

      assert log.details == %{
               "action" => "update",
               "changeset_action" => "update",
               "id" => anti_abuse_record.id
             }

      # Test the update didn't go through
      assert anti_abuse_record == Moderation.get_anti_abuse_record(anti_abuse_record.id, scope)
    end

    test "delete_anti_abuse_record/1 deletes the anti_abuse_record", %{user: user, scope: scope} do
      anti_abuse_record = anti_abuse_record_fixture(scope)

      assert {:ok, %AntiAbuseRecord{}} =
               Moderation.delete_anti_abuse_record(anti_abuse_record, scope)

      log = get_most_recent_audit_log_for_user(user.id)
      assert log.action == "Anti-abuse record access"

      assert log.details == %{
               "action" => "delete",
               "id" => anti_abuse_record.id
             }

      assert Moderation.get_anti_abuse_record(anti_abuse_record.id, scope) == nil

      log = get_most_recent_audit_log_for_user(user.id)
      assert log.action == "Anti-abuse record access"

      assert log.details == %{
               "action" => "get",
               "id" => nil
             }
    end
  end
end
