defmodule TeiserverWeb.Live.Account.Profile.MatchesTest do
  use TeiserverWeb.ConnCase, async: false

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.{Account, Config, TeiserverTestLib}
  alias TeiserverWeb.Account.ProfileLive.Matches

  setup do
    {:ok, data} =
      TeiserverTestLib.player_permissions()
      |> GeneralTestLib.conn_setup()
      |> TeiserverTestLib.conn_setup()

    profile_user = GeneralTestLib.make_user()

    %{conn: data[:conn], viewer: data[:user], profile_user: profile_user}
  end

  describe "privacy controls with actual relationships" do
    test "self can always view their own matches and ratings", %{
      viewer: viewer,
      profile_user: _profile_user
    } do
      profile_user = viewer

      for privacy_setting <- ["Only myself", "Friends", "Any player", "Completely public"] do
        Config.set_user_config(
          profile_user.id,
          "privacy.Match history visibility",
          privacy_setting
        )

        Config.set_user_config(profile_user.id, "privacy.Ratings visibility", privacy_setting)

        assert Matches.can_view_match_history?(profile_user, [:self]) == true
        assert Matches.can_view_ratings?(profile_user, [:self]) == true
      end
    end

    test "friend can view when privacy allows friends", %{
      viewer: viewer,
      profile_user: profile_user
    } do
      {:ok, _friend} = Account.create_friend(viewer.id, profile_user.id)

      Config.set_user_config(profile_user.id, "privacy.Match history visibility", "Friends")
      Config.set_user_config(profile_user.id, "privacy.Ratings visibility", "Friends")

      assert Matches.can_view_match_history?(profile_user, [:friend]) == true
      assert Matches.can_view_ratings?(profile_user, [:friend]) == true

      Config.set_user_config(profile_user.id, "privacy.Match history visibility", "Only myself")
      Config.set_user_config(profile_user.id, "privacy.Ratings visibility", "Only myself")

      assert Matches.can_view_match_history?(profile_user, [:friend]) == false
      assert Matches.can_view_ratings?(profile_user, [:friend]) == false
    end

    test "stranger can view when privacy allows any player", %{
      viewer: _viewer,
      profile_user: profile_user
    } do
      Config.set_user_config(profile_user.id, "privacy.Match history visibility", "Any player")
      Config.set_user_config(profile_user.id, "privacy.Ratings visibility", "Any player")

      assert Matches.can_view_match_history?(profile_user, []) == true
      assert Matches.can_view_ratings?(profile_user, []) == true

      Config.set_user_config(profile_user.id, "privacy.Match history visibility", "Friends")
      Config.set_user_config(profile_user.id, "privacy.Ratings visibility", "Friends")

      assert Matches.can_view_match_history?(profile_user, []) == false
      assert Matches.can_view_ratings?(profile_user, []) == false
    end

    test "blocked user can view with completely public settings", %{
      viewer: viewer,
      profile_user: profile_user
    } do
      {:ok, _block} = Account.block_user(profile_user.id, viewer.id)

      Config.set_user_config(
        profile_user.id,
        "privacy.Match history visibility",
        "Completely public"
      )

      Config.set_user_config(profile_user.id, "privacy.Ratings visibility", "Completely public")

      assert Matches.can_view_match_history?(profile_user, [:block, :avoid, :ignore]) == true
      assert Matches.can_view_ratings?(profile_user, [:block, :avoid, :ignore]) == true

      Config.set_user_config(profile_user.id, "privacy.Match history visibility", "Any player")
      Config.set_user_config(profile_user.id, "privacy.Ratings visibility", "Any player")

      assert Matches.can_view_match_history?(profile_user, [:block, :avoid, :ignore]) == false
      assert Matches.can_view_ratings?(profile_user, [:block, :avoid, :ignore]) == false
    end

    test "avoided user can view with completely public settings", %{
      viewer: viewer,
      profile_user: profile_user
    } do
      {:ok, _avoid} = Account.avoid_user(profile_user.id, viewer.id)

      Config.set_user_config(
        profile_user.id,
        "privacy.Match history visibility",
        "Completely public"
      )

      Config.set_user_config(profile_user.id, "privacy.Ratings visibility", "Completely public")

      assert Matches.can_view_match_history?(profile_user, [:avoid, :ignore]) == true
      assert Matches.can_view_ratings?(profile_user, [:avoid, :ignore]) == true

      Config.set_user_config(profile_user.id, "privacy.Match history visibility", "Any player")
      Config.set_user_config(profile_user.id, "privacy.Ratings visibility", "Any player")

      assert Matches.can_view_match_history?(profile_user, [:avoid, :ignore]) == false
      assert Matches.can_view_ratings?(profile_user, [:avoid, :ignore]) == false
    end

    test "ignored user can view with completely public settings", %{
      viewer: viewer,
      profile_user: profile_user
    } do
      {:ok, _ignore} = Account.ignore_user(profile_user.id, viewer.id)

      Config.set_user_config(
        profile_user.id,
        "privacy.Match history visibility",
        "Completely public"
      )

      Config.set_user_config(profile_user.id, "privacy.Ratings visibility", "Completely public")

      assert Matches.can_view_match_history?(profile_user, [:ignore]) == true
      assert Matches.can_view_ratings?(profile_user, [:ignore]) == true

      Config.set_user_config(profile_user.id, "privacy.Match history visibility", "Any player")
      Config.set_user_config(profile_user.id, "privacy.Ratings visibility", "Any player")

      assert Matches.can_view_match_history?(profile_user, [:ignore]) == false
      assert Matches.can_view_ratings?(profile_user, [:ignore]) == false
    end
  end
end
