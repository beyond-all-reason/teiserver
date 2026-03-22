defmodule TeiserverWeb.Microblog.PostFormComponentTest do
  @moduledoc false

  alias Teiserver.AccountFixtures
  alias Teiserver.Microblog
  alias TeiserverWeb.Microblog.PostFormComponent

  use TeiserverWeb.ConnCase

  test "create_post works with or without poster_alias" do
    user = AccountFixtures.user_fixture()

    post_params = %{
      "contents" => "test",
      "discord_channel_id" => "",
      "poster_alias" => "",
      "poster_id" => user.id,
      "summary" => "test",
      "title" => "test"
    }

    {:ok, result} = Microblog.create_post(post_params)
    assert result.poster_alias == nil

    post_params = %{
      "contents" => "test",
      "discord_channel_id" => "",
      "poster_alias" => "Jenny",
      "poster_id" => user.id,
      "summary" => "test",
      "title" => "test"
    }

    {:ok, result} = Microblog.create_post(post_params)
    assert result.poster_alias == "Jenny"
  end

  test "Get discord text when discord id present" do
    user = AccountFixtures.user_fixture()

    post_params = %{
      "contents" => "test",
      "discord_channel_id" => "",
      "poster_alias" => "contributor alias",
      "poster_id" => user.id,
      "summary" => "test",
      "title" => "test"
    }

    {:ok, post} = Microblog.create_post(post_params)

    user = %{
      discord_id: "mydiscordname",
      name: "ign"
    }

    host = "localhost"

    result = PostFormComponent.create_discord_text(user, post, host)

    assert String.contains?(result, "Posted by <@mydiscordname>")
  end

  test "Get discord text when discord id not present and alias is present" do
    user = AccountFixtures.user_fixture()

    post_params = %{
      "contents" => "test",
      "discord_channel_id" => "",
      "poster_alias" => "contributoralias",
      "poster_id" => user.id,
      "summary" => "test",
      "title" => "test"
    }

    {:ok, post} = Microblog.create_post(post_params)

    user = %{
      discord_id: nil,
      name: "ign"
    }

    host = "localhost"

    result = PostFormComponent.create_discord_text(user, post, host)

    assert String.contains?(result, "Posted by contributoralias")
  end

  test "Get discord text when discord id not present and alias not present" do
    user = AccountFixtures.user_fixture()

    post_params = %{
      "contents" => "test",
      "discord_channel_id" => "",
      "poster_alias" => "",
      "poster_id" => user.id,
      "summary" => "test",
      "title" => "test"
    }

    {:ok, post} = Microblog.create_post(post_params)

    user = %{
      discord_id: nil,
      name: "ingame_name"
    }

    host = "localhost"

    result = PostFormComponent.create_discord_text(user, post, host)

    assert String.contains?(result, "Posted by ingame_name")
  end
end
