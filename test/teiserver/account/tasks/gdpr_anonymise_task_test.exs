defmodule Teiserver.Account.GDPRAnonymiseTaskTest do
  alias Teiserver.Account
  alias Teiserver.Account.GDPRAnonymiseTask
  alias Teiserver.Account.SmurfKeyQueries
  alias Teiserver.Account.User
  alias Teiserver.AccountFixtures
  alias Teiserver.Coordinator.CoordinatorServer
  alias Teiserver.Microblog.PostQueries
  alias Teiserver.Microblog.UploadQueries
  alias Teiserver.MicroblogFixtures
  alias Teiserver.Moderation.AntiAbuseRecord
  alias Teiserver.Moderation.RestoreAnonymisedUserTask
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

      # Sleep, just to ensure we have done everything in the task
      :timer.sleep(500)

      updated_user = Account.get_user!(user.id)
      assert updated_user.name == user.name

      # No AAR created
      assert RestoreAnonymisedUserTask.find_record_from_identifier(:email, user.email) == nil
    end

    test "empty user" do
      user =
        AccountFixtures.user_fixture()
        |> User.set_gdpr_forget_changeset(%{gdpr_forget_after: @old_forget_datetime})
        |> Repo.update!()

      :ok = GDPRAnonymiseTask.perform(%{})

      # Sleep, just to ensure we have done everything in the task
      :timer.sleep(500)

      updated_user = Account.get_user!(user.id)
      assert updated_user.name != user.name

      # AAR created
      assert %AntiAbuseRecord{} =
               RestoreAnonymisedUserTask.find_record_from_identifier(:email, user.email)
    end

    test "User with references" do
      user =
        AccountFixtures.user_fixture()
        |> User.set_gdpr_forget_changeset(%{gdpr_forget_after: @old_forget_datetime})
        |> Repo.update!()

      {:ok, _user_key1} = Account.create_smurf_key(user.id, "test-key1", "test-value")
      {:ok, _user_key2} = Account.create_smurf_key(user.id, "test-key2", "test-value2")

      _user_post1 = MicroblogFixtures.post_fixture(%{poster_id: user.id})
      _user_post2 = MicroblogFixtures.post_fixture(%{poster_id: user.id})

      _user_upload1 = MicroblogFixtures.upload_fixture(%{uploader_id: user.id})
      _user_upload2 = MicroblogFixtures.upload_fixture(%{uploader_id: user.id})

      :ok = GDPRAnonymiseTask.perform(%{})

      # Sleep, just to ensure we have done everything in the task
      :timer.sleep(500)

      updated_user = Account.get_user!(user.id)
      assert updated_user.name != user.name

      # AAR created
      assert %AntiAbuseRecord{} =
               RestoreAnonymisedUserTask.find_record_from_identifier(:email, user.email)

      # No smurf keys, posts or uploads
      keys =
        SmurfKeyQueries.smurf_keys()
        |> SmurfKeyQueries.where_user_id(user.id)
        |> Repo.all()

      assert Enum.empty?(keys)

      posts =
        PostQueries.posts()
        |> PostQueries.where_poster_id(user.id)
        |> Repo.all()

      assert Enum.empty?(posts)

      uploads =
        UploadQueries.uploads()
        |> UploadQueries.where_uploader_id(user.id)
        |> Repo.all()

      assert Enum.empty?(uploads)
    end
  end
end
