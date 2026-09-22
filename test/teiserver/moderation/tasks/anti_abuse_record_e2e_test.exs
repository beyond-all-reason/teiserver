defmodule Teiserver.Moderation.GDPRAnonymiseAndRestoreTest do
  alias Teiserver.Account
  alias Teiserver.Account.RestoreAnonymisedUserTask
  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Logging.LoggingTestLib
  alias Teiserver.MicroblogFixtures
  alias Teiserver.Moderation
  alias Teiserver.Moderation.AntiAbuseRecord
  alias Teiserver.Moderation.CreateAntiAbuseRecordTask
  alias Teiserver.Moderation.RefreshUserRestrictionsTask

  use Teiserver.DataCase, async: false

  describe "GDPR AAR create and restore" do
    test "empty user" do
      # Create a user, anonymise them, restore them
      user = AccountFixtures.user_fixture()
      admin = AccountFixtures.user_fixture()
      scope = GeneralTestLib.scope_fixture(admin)

      # Need to define this as a value since we can't later use it inside
      # a match
      user_id = user.id

      {:ok, _action} =
        Moderation.create_action(%{
          target_id: user.id,
          reason: "reason",
          restrictions: ["Login"],
          expires: DateTime.utc_now() |> DateTime.shift(year: 1),
          score_modifier: 0
        })

      RefreshUserRestrictionsTask.refresh_user(user.id)

      {:ok, %AntiAbuseRecord{} = record} =
        CreateAntiAbuseRecordTask.create_anti_abuse_record_from_user_id(
          user.id,
          scope,
          "no notes"
        )

      # We will test the contents shortly but for now we want to be sure
      # we have not created keys in the wrong places
      assert match?(
               %{
                 user_id: ^user_id,
                 clean: false,
                 notes: "no notes",
                 restored_by_id: nil,
                 restored_at: nil,
                 hashes: %{
                   email: "" <> _email,
                   discord_id: nil,
                   steam_id: nil,
                   decrypt_keys: %{
                     email: "" <> _email_key,
                     discord_id: nil,
                     steam_id: nil
                   },
                   restore_data: "" <> _encrypted_data
                 }
               },
               record
             )

      # Assert we have created the audit log too
      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(admin.id)

      assert match?(
               %{
                 action: "Anti-abuse record access",
                 details: %{"action" => "create"}
               },
               audit_log
             )

      # Next up, we need to ensure we can find the record
      assert is_nil(
               RestoreAnonymisedUserTask.find_record_from_identifier(:discord_id, user.email)
             )

      assert is_nil(RestoreAnonymisedUserTask.find_record_from_identifier(:steam_id, user.email))

      found_record = RestoreAnonymisedUserTask.find_record_from_identifier(:email, user.email)

      # The items are not identical because the record hashes uses atoms for keys as it
      # is from the changeset, both having the same ID is acceptable as a check because we use UUIDs
      # for AARs and as such won't accidentally end up with an identical ID
      assert found_record.id == record.id

      # Assert that this has not come back in an unencrypted format
      assert match?(
               {:error, %Jason.DecodeError{}},
               Jason.decode(found_record.hashes["restore_data"])
             )

      # Now can we restore it?
      # TODO actually restore it, for now we just want to ensure the decode process works
      restore_data =
        RestoreAnonymisedUserTask.restore_from_record(found_record, scope, :email, user.email)

      assert restore_data ==
               {:ok,
                %{
                  "post_ids" => [],
                  "upload_ids" => [],
                  "smurf_key_ids" => []
                }}
    end
  end

  test "User with references" do
    # Create a user, anonymise them, restore them
    user = AccountFixtures.user_fixture()
    admin = AccountFixtures.user_fixture()
    scope = GeneralTestLib.scope_fixture(admin)

    # Create entities against both the user and the admin to ensure only the user
    # linked stuff gets changed
    {:ok, user_key1} = Account.create_smurf_key(user.id, "test-key3", "test-value")
    {:ok, user_key2} = Account.create_smurf_key(user.id, "test-key4", "test-value2")
    {:ok, _admin_key} = Account.create_smurf_key(admin.id, "admin-key", "admin-value")

    user_post1 = MicroblogFixtures.post_fixture(%{poster_id: user.id})
    user_post2 = MicroblogFixtures.post_fixture(%{poster_id: user.id})
    _admin_post = MicroblogFixtures.post_fixture(%{poster_id: admin.id})

    user_upload1 = MicroblogFixtures.upload_fixture(%{uploader_id: user.id})
    user_upload2 = MicroblogFixtures.upload_fixture(%{uploader_id: user.id})
    _admin_upload = MicroblogFixtures.upload_fixture(%{uploader_id: admin.id})

    # Need to define this as a value since we can't later use it inside
    # a match
    user_id = user.id

    {:ok, _action} =
      Moderation.create_action(%{
        target_id: user.id,
        reason: "reason",
        restrictions: ["Login"],
        expires: DateTime.utc_now() |> DateTime.shift(year: 1),
        score_modifier: 0
      })

    RefreshUserRestrictionsTask.refresh_user(user.id)

    {:ok, %AntiAbuseRecord{} = record} =
      CreateAntiAbuseRecordTask.create_anti_abuse_record_from_user_id(
        user.id,
        scope,
        "no notes"
      )

    # We will test the contents shortly but for now we want to be sure
    # we have not created keys in the wrong places
    assert match?(
             %{
               user_id: ^user_id,
               clean: false,
               notes: "no notes",
               restored_by_id: nil,
               restored_at: nil,
               hashes: %{
                 email: "" <> _email,
                 discord_id: nil,
                 steam_id: nil,
                 decrypt_keys: %{
                   email: "" <> _email_key,
                   discord_id: nil,
                   steam_id: nil
                 },
                 restore_data: "" <> _encrypted_data
               }
             },
             record
           )

    # Assert we have created the audit log too
    audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(admin.id)

    assert match?(
             %{
               action: "Anti-abuse record access",
               details: %{"action" => "create"}
             },
             audit_log
           )

    # Next up, we need to ensure we can find the record
    assert is_nil(RestoreAnonymisedUserTask.find_record_from_identifier(:discord_id, user.email))

    assert is_nil(RestoreAnonymisedUserTask.find_record_from_identifier(:steam_id, user.email))

    found_record = RestoreAnonymisedUserTask.find_record_from_identifier(:email, user.email)

    # The items are not identical because the record hashes uses atoms for keys as it
    # is from the changeset, both having the same ID is acceptable as a check because we use UUIDs
    # for AARs and as such won't accidentally end up with an identical ID
    assert found_record.id == record.id

    # Assert that this has not come back in an unencrypted format
    assert match?(
             {:error, %Jason.DecodeError{}},
             Jason.decode(found_record.hashes["restore_data"])
           )

    # Dry run restore, full tests for post-processing exist in
    # Teiserver.Account.GDPRAnonymiseTaskTest
    restore_data =
      RestoreAnonymisedUserTask.restore_from_record(found_record, scope, :email, user.email)

    assert restore_data ==
             {:ok,
              %{
                "post_ids" => [user_post1.id, user_post2.id],
                "upload_ids" => Enum.sort([user_upload1.id, user_upload2.id]),
                "smurf_key_ids" => [user_key1.id, user_key2.id]
              }}
  end
end
