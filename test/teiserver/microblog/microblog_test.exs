defmodule Teiserver.MicroblogTest do
  @moduledoc false
  use Teiserver.DataCase

  alias Teiserver.Microblog

  describe "tags" do
    alias Teiserver.Microblog.Tag

    import Teiserver.MicroblogFixtures

    @invalid_attrs %{colour: nil, icon: nil, name: nil}

    test "list_tags/0 returns all tags" do
      tag = tag_fixture()
      assert Microblog.list_tags() == [tag]
    end

    test "get_tag!/1 returns the tag with given id" do
      tag = tag_fixture()
      assert Microblog.get_tag!(tag.id) == tag
    end

    test "create_tag/1 with valid data creates a tag" do
      valid_attrs = %{colour: "#AA0000", icon: "some icon", name: "some name"}

      assert {:ok, %Tag{} = tag} = Microblog.create_tag(valid_attrs)
      assert tag.colour == "#AA0000"
      assert tag.icon == "some icon"
      assert tag.name == "some name"
    end

    test "create_tag/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Microblog.create_tag(@invalid_attrs)
    end

    test "update_tag/2 with valid data updates the tag" do
      tag = tag_fixture()
      update_attrs = %{colour: "#0000AA", icon: "some updated icon", name: "some updated name"}

      assert {:ok, %Tag{} = tag} = Microblog.update_tag(tag, update_attrs)
      assert tag.colour == "#0000AA"
      assert tag.icon == "some updated icon"
      assert tag.name == "some updated name"
    end

    test "update_tag/2 with invalid data returns error changeset" do
      tag = tag_fixture()
      assert {:error, %Ecto.Changeset{}} = Microblog.update_tag(tag, @invalid_attrs)
      assert tag == Microblog.get_tag!(tag.id)
    end

    test "delete_tag/1 deletes the tag" do
      tag = tag_fixture()
      assert {:ok, %Tag{}} = Microblog.delete_tag(tag)
      assert_raise Ecto.NoResultsError, fn -> Microblog.get_tag!(tag.id) end
    end

    test "change_tag/1 returns a tag changeset" do
      tag = tag_fixture()
      assert %Ecto.Changeset{} = Microblog.change_tag(tag)
    end
  end

  describe "posts" do
    alias Teiserver.Microblog.Post

    import Teiserver.{AccountFixtures, MicroblogFixtures}

    @invalid_attrs %{
      contents: nil,
      discord_post_id: nil,
      title: nil,
      view_count: nil,
      poster_id: nil
    }

    test "list_posts/0 returns all posts" do
      post = post_fixture()
      assert Microblog.list_posts() == [post]
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture()
      assert Microblog.get_post!(post.id) == post
    end

    test "create_post/1 with valid data creates a post" do
      user = user_fixture()

      valid_attrs = %{
        contents: "some contents",
        discord_post_id: 42,
        title: "some title",
        view_count: 42,
        poster_id: user.id
      }

      assert {:ok, %Post{} = post} = Microblog.create_post(valid_attrs)
      assert post.contents == "some contents"
      assert post.discord_post_id == 42
      assert post.title == "some title"
      assert post.view_count == 42
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Microblog.create_post(@invalid_attrs)
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()

      update_attrs = %{
        contents: "some updated contents",
        discord_post_id: 43,
        title: "some updated title",
        view_count: 43
      }

      assert {:ok, %Post{} = post} = Microblog.update_post(post, update_attrs, :updated)
      assert post.contents == "some updated contents"
      assert post.discord_post_id == 43
      assert post.title == "some updated title"
      assert post.view_count == 43
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = post_fixture()
      assert {:error, %Ecto.Changeset{}} = Microblog.update_post(post, @invalid_attrs, :updated)
      assert post == Microblog.get_post!(post.id)
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Microblog.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Microblog.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Microblog.change_post(post)
    end
  end

  describe "post_tags" do
    alias Teiserver.Microblog.PostTag

    import Teiserver.MicroblogFixtures

    @invalid_attrs %{post_id: nil, tag_id: nil}

    test "list_post_tags/0 returns all post_tags" do
      post_tag = post_tag_fixture()
      assert Microblog.list_post_tags() == [post_tag]
    end

    test "get_post_tag!/1 returns the post_tag with given id" do
      post_tag = post_tag_fixture()
      assert Microblog.get_post_tag!(post_tag.post_id, post_tag.tag_id) == post_tag
    end

    test "create_post_tag/1 with valid data creates a post_tag" do
      post = post_fixture()
      tag = tag_fixture()
      valid_attrs = %{post_id: post.id, tag_id: tag.id}

      assert {:ok, %PostTag{} = _post_tag} = Microblog.create_post_tag(valid_attrs)
    end

    test "create_post_tag/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Microblog.create_post_tag(@invalid_attrs)
    end

    test "update_post_tag/2 with valid data updates the post_tag" do
      post_tag = post_tag_fixture()
      update_attrs = %{}

      assert {:ok, %PostTag{} = _post_tag} = Microblog.update_post_tag(post_tag, update_attrs)
    end

    test "update_post_tag/2 with invalid data returns error changeset" do
      post_tag = post_tag_fixture()
      assert {:error, %Ecto.Changeset{}} = Microblog.update_post_tag(post_tag, @invalid_attrs)
      assert post_tag == Microblog.get_post_tag!(post_tag.post_id, post_tag.tag_id)
    end

    test "delete_post_tag/1 deletes the post_tag" do
      post_tag = post_tag_fixture()
      assert {:ok, %PostTag{}} = Microblog.delete_post_tag(post_tag)

      assert_raise Ecto.NoResultsError, fn ->
        Microblog.get_post_tag!(post_tag.post_id, post_tag.tag_id)
      end
    end

    test "change_post_tag/1 returns a post_tag changeset" do
      post_tag = post_tag_fixture()
      assert %Ecto.Changeset{} = Microblog.change_post_tag(post_tag)
    end
  end

  describe "user_preferences" do
    alias Teiserver.Microblog.UserPreference

    import Teiserver.{AccountFixtures, MicroblogFixtures}

    @invalid_attrs %{
      disabled_posters: nil,
      disabled_tags: nil,
      enabled_posters: nil,
      enabled_tags: nil,
      tag_mode: nil,
      user_id: nil
    }

    test "list_user_preferences/0 returns all user_preferences" do
      user_preference = user_preference_fixture()
      assert Microblog.list_user_preferences() == [user_preference]
    end

    test "get_user_preference!/1 returns the user_preference with given id" do
      user_preference = user_preference_fixture()
      assert Microblog.get_user_preference!(user_preference.user_id) == user_preference
    end

    test "create_user_preference/1 with valid data creates a user_preference" do
      user = user_fixture()

      valid_attrs = %{
        disabled_posters: [1, 2],
        disabled_tags: [1, 2],
        enabled_posters: [1, 2],
        enabled_tags: [1, 2],
        tag_mode: "some tag_mode",
        user_id: user.id
      }

      assert {:ok, %UserPreference{} = user_preference} =
               Microblog.create_user_preference(valid_attrs)

      assert user_preference.disabled_posters == [1, 2]
      assert user_preference.disabled_tags == [1, 2]
      assert user_preference.enabled_posters == [1, 2]
      assert user_preference.enabled_tags == [1, 2]
      assert user_preference.tag_mode == "some tag_mode"
    end

    test "create_user_preference/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Microblog.create_user_preference(@invalid_attrs)
    end

    test "update_user_preference/2 with valid data updates the user_preference" do
      user_preference = user_preference_fixture()

      update_attrs = %{
        disabled_posters: [1],
        disabled_tags: [1],
        enabled_posters: [1],
        enabled_tags: [1],
        tag_mode: "some updated tag_mode"
      }

      assert {:ok, %UserPreference{} = user_preference} =
               Microblog.update_user_preference(user_preference, update_attrs)

      assert user_preference.disabled_posters == [1]
      assert user_preference.disabled_tags == [1]
      assert user_preference.enabled_posters == [1]
      assert user_preference.enabled_tags == [1]
      assert user_preference.tag_mode == "some updated tag_mode"
    end

    test "update_user_preference/2 with invalid data returns error changeset" do
      user_preference = user_preference_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Microblog.update_user_preference(user_preference, @invalid_attrs)

      assert user_preference == Microblog.get_user_preference!(user_preference.user_id)
    end

    test "delete_user_preference/1 deletes the user_preference" do
      user_preference = user_preference_fixture()
      assert {:ok, %UserPreference{}} = Microblog.delete_user_preference(user_preference)

      assert_raise Ecto.NoResultsError, fn ->
        Microblog.get_user_preference!(user_preference.user_id)
      end
    end

    test "change_user_preference/1 returns a user_preference changeset" do
      user_preference = user_preference_fixture()
      assert %Ecto.Changeset{} = Microblog.change_user_preference(user_preference)
    end
  end

  describe "poll_responses" do
    alias Teiserver.Microblog.PollResponse

    import Teiserver.MicroblogFixtures

    @invalid_attrs %{post_id: nil, tag_id: nil}

    test "list_poll_responses/0 returns all poll_responses" do
      poll_response = poll_response_fixture()
      assert Microblog.list_poll_responses() == [poll_response]
    end

    test "get_poll_response/1 returns the poll_response with given id" do
      poll_response = poll_response_fixture()

      assert Microblog.get_poll_response(poll_response.user_id, poll_response.post_id) ==
               poll_response
    end

    test "create_poll_response/1 with valid data creates a poll_response" do
      post = post_fixture()
      user = Teiserver.AccountFixtures.user_fixture()
      valid_attrs = %{post_id: post.id, user_id: user.id, response: "A"}

      assert {:ok, %PollResponse{} = _poll_response} = Microblog.create_poll_response(valid_attrs)
    end

    test "create_poll_response/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Microblog.create_poll_response(@invalid_attrs)
    end

    test "update_poll_response/2 with valid data updates the poll_response" do
      poll_response = poll_response_fixture()
      update_attrs = %{}

      assert {:ok, %PollResponse{} = _poll_response} =
               Microblog.update_poll_response(poll_response, update_attrs)
    end

    test "update_poll_response/2 with invalid data returns error changeset" do
      poll_response = poll_response_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Microblog.update_poll_response(poll_response, @invalid_attrs)

      assert poll_response ==
               Microblog.get_poll_response(poll_response.user_id, poll_response.post_id)
    end

    test "delete_poll_response/1 deletes the poll_response" do
      poll_response = poll_response_fixture()
      assert {:ok, %PollResponse{}} = Microblog.delete_poll_response(poll_response)

      assert Microblog.get_poll_response(poll_response.user_id, poll_response.post_id) == nil
    end

    test "change_poll_response/1 returns a poll_response changeset" do
      poll_response = poll_response_fixture()
      assert %Ecto.Changeset{} = Microblog.change_poll_response(poll_response)
    end
  end

  describe "uploads" do
    alias Teiserver.Microblog.Upload

    import Teiserver.{AccountFixtures, MicroblogFixtures}

    @invalid_attrs %{
      filename: nil,
      type: nil,
      file_size: nil
    }

    test "list_uploads/0 returns all uploads" do
      upload = upload_fixture()
      assert Microblog.list_uploads() == [upload]
    end

    test "get_upload!/1 returns the upload with given id" do
      upload = upload_fixture()
      assert Microblog.get_upload!(upload.id) == upload
    end

    test "create_upload/1 with valid data creates a upload" do
      user = user_fixture()

      valid_attrs = %{
        filename: "some contents",
        type: "some title",
        file_size: 42,
        uploader_id: user.id
      }

      assert {:ok, %Upload{} = upload} = Microblog.create_upload(valid_attrs)
      assert upload.filename == "some contents"
      assert upload.type == "some title"
      assert upload.file_size == 42
    end

    test "create_upload/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Microblog.create_upload(@invalid_attrs)
    end

    test "update_upload/2 with valid data updates the upload" do
      upload = upload_fixture()
      user = user_fixture()

      update_attrs = %{
        filename: "some updated contents",
        type: "some updated title",
        file_size: 43,
        uploader_id: user.id
      }

      assert {:ok, %Upload{} = _upload} = Microblog.update_upload(upload, update_attrs)
    end

    test "update_upload/2 with invalid data returns error changeset" do
      upload = upload_fixture()
      assert {:error, %Ecto.Changeset{}} = Microblog.update_upload(upload, @invalid_attrs)
      assert upload == Microblog.get_upload!(upload.id)
    end

    test "delete_upload/1 deletes the upload" do
      upload = upload_fixture()
      assert {:ok, %Upload{}} = Microblog.delete_upload(upload)
      assert_raise Ecto.NoResultsError, fn -> Microblog.get_upload!(upload.id) end
    end

    test "change_upload/1 returns a upload changeset" do
      upload = upload_fixture()
      assert %Ecto.Changeset{} = Microblog.change_upload(upload)
    end
  end
end
