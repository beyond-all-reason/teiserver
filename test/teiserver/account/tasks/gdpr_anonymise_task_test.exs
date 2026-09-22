defmodule Teiserver.Account.GDPRAnonymiseTaskTest do
  alias Teiserver.Account
  alias Teiserver.Account.GDPRAnonymiseTask
  alias Teiserver.Account.RestoreAnonymisedUserTask
  alias Teiserver.Account.SmurfKeyQueries
  alias Teiserver.Account.User
  alias Teiserver.AccountFixtures
  alias Teiserver.Coordinator.CoordinatorServer
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Microblog.PostQueries
  alias Teiserver.Microblog.UploadQueries
  alias Teiserver.MicroblogFixtures
  alias Teiserver.Moderation.AntiAbuseRecord
  alias Teiserver.Repo

  use Teiserver.DataCase, async: false

  # A date outside of the cooldown window
  @old_forget_datetime DateTime.utc_now() |> DateTime.shift(year: -1)

  # A date within the cooldown window
  @recent_forget_datetime DateTime.utc_now() |> DateTime.shift(day: -1)

  setup do
    CoordinatorServer.make_and_cache_coordinator_account()
    :ok
  end

  describe "GDPR anonymise and restore" do
    test "only users outside of cooldown window" do
      user =
        AccountFixtures.user_fixture()
        |> User.set_gdpr_forget_changeset(%{gdpr_forget_after: @recent_forget_datetime})
        |> Repo.update!()

      :ok = GDPRAnonymiseTask.perform(%{})

      updated_user = Account.get_user!(user.id)
      assert updated_user.name == user.name

      # No AAR created
      assert RestoreAnonymisedUserTask.find_record_from_identifier(:email, user.email) == nil
    end

    test "empty user" do
      scope =
        AccountFixtures.user_fixture()
        |> GeneralTestLib.scope_fixture()

      user =
        AccountFixtures.user_fixture()
        |> User.set_gdpr_forget_changeset(%{gdpr_forget_after: @old_forget_datetime})
        |> Repo.update!()

      :ok = GDPRAnonymiseTask.perform(%{})

      updated_user = Account.get_user!(user.id)
      assert updated_user.name != user.name
      assert updated_user.roles == ["GDPR forgotten"]

      # AAR created
      assert record =
               %AntiAbuseRecord{} =
               RestoreAnonymisedUserTask.find_record_from_identifier(:email, user.email)

      # Try a dry-run
      {:ok, dry_run_result} =
        RestoreAnonymisedUserTask.restore_from_record(record, scope, :email, user.email)

      assert dry_run_result == %{"post_ids" => [], "smurf_key_ids" => [], "upload_ids" => []}

      # Try a restore, nothing should change but we want to ensure there's not an error when we do it
      result =
        RestoreAnonymisedUserTask.restore_from_record(record, scope, :email, user.email, true)

      assert result == {:ok, :success}
    end

    test "User with references" do
      scope =
        AccountFixtures.user_fixture()
        |> GeneralTestLib.scope_fixture()

      user =
        AccountFixtures.user_fixture()
        |> User.set_gdpr_forget_changeset(%{gdpr_forget_after: @old_forget_datetime})
        |> Repo.update!()

      {:ok, user_key1} = Account.create_smurf_key(user.id, "test-key1", "test-value")
      {:ok, user_key2} = Account.create_smurf_key(user.id, "test-key2", "test-value2")

      user_post1 = MicroblogFixtures.post_fixture(%{poster_id: user.id})
      user_post2 = MicroblogFixtures.post_fixture(%{poster_id: user.id})

      user_upload1 = MicroblogFixtures.upload_fixture(%{uploader_id: user.id})
      user_upload2 = MicroblogFixtures.upload_fixture(%{uploader_id: user.id})

      # Ensure the items we created exist and we are counting them the correct way
      key_count =
        SmurfKeyQueries.smurf_keys()
        |> SmurfKeyQueries.where_user_id(user.id)
        |> QueryHelpers.count()

      assert key_count == 2

      post_count =
        PostQueries.posts()
        |> PostQueries.where_poster_id(user.id)
        |> QueryHelpers.count()

      assert post_count == 2

      upload_count =
        UploadQueries.uploads()
        |> UploadQueries.where_uploader_id(user.id)
        |> QueryHelpers.count()

      assert upload_count == 2

      :ok = GDPRAnonymiseTask.perform(%{})

      updated_user = Account.get_user!(user.id)
      assert updated_user.name != user.name
      assert updated_user.roles == ["GDPR forgotten"]

      # AAR created
      assert record =
               %AntiAbuseRecord{} =
               RestoreAnonymisedUserTask.find_record_from_identifier(:email, user.email)

      # No smurf keys, posts or uploads
      key_count =
        SmurfKeyQueries.smurf_keys()
        |> SmurfKeyQueries.where_user_id(user.id)
        |> QueryHelpers.count()

      assert key_count == 0

      post_count =
        PostQueries.posts()
        |> PostQueries.where_poster_id(user.id)
        |> QueryHelpers.count()

      assert post_count == 0

      upload_count =
        UploadQueries.uploads()
        |> UploadQueries.where_uploader_id(user.id)
        |> QueryHelpers.count()

      assert upload_count == 0

      # Try a dry-run
      {:ok, dry_run_result} =
        RestoreAnonymisedUserTask.restore_from_record(record, scope, :email, user.email)

      # No promise the keys are in order so we need to sort them
      assert Enum.sort(dry_run_result["post_ids"]) == Enum.sort([user_post1.id, user_post2.id])

      assert Enum.sort(dry_run_result["upload_ids"]) ==
               Enum.sort([user_upload1.id, user_upload2.id])

      assert Enum.sort(dry_run_result["smurf_key_ids"]) == Enum.sort([user_key1.id, user_key2.id])

      # Try a restore, the result should be :ok and then we verify other changes were made correctly
      result =
        RestoreAnonymisedUserTask.restore_from_record(record, scope, :email, user.email, true)

      assert result == {:ok, :success}

      key_count =
        SmurfKeyQueries.smurf_keys()
        |> SmurfKeyQueries.where_user_id(user.id)
        |> QueryHelpers.count()

      assert key_count == 2

      post_count =
        PostQueries.posts()
        |> PostQueries.where_poster_id(user.id)
        |> QueryHelpers.count()

      assert post_count == 2

      upload_count =
        UploadQueries.uploads()
        |> UploadQueries.where_uploader_id(user.id)
        |> QueryHelpers.count()

      assert upload_count == 2

      restored_user = Account.get_user(user.id)
      assert restored_user.email == user.email
      assert restored_user.roles == ["Verified"]
    end
  end
end
