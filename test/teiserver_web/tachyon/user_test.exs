defmodule TeiserverWeb.Tachyon.UserTest do
  alias Teiserver.Account
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Moderation
  alias Teiserver.Player
  alias Teiserver.Support.Tachyon
  use TeiserverWeb.ConnCase, async: false

  setup [{Tachyon, :setup_client}]

  describe "report" do
    test "one report per target", %{user: user, client: client} do
      {:ok, ctx2} = Tachyon.setup_client()
      {:ok, ctx3} = Tachyon.setup_client()

      assert %{"status" => "success"} =
               Tachyon.report_user!(client, [ctx2[:user].id, ctx3[:user].id], "chat",
                 message: "spamming the lobby"
               )

      reports = Moderation.list_reports(search: [reporter_id: user.id])

      assert MapSet.new(reports, & &1.target_id) ==
               MapSet.new([ctx2[:user].id, ctx3[:user].id])

      assert Enum.all?(reports, &(&1.type == "chat"))
      assert Enum.all?(reports, &(&1.sub_type == "other"))
      assert Enum.all?(reports, &(&1.extra_text == "spamming the lobby"))
    end

    test "message is optional", %{user: user, client: client} do
      {:ok, ctx2} = Tachyon.setup_client()

      assert %{"status" => "success"} =
               Tachyon.report_user!(client, [ctx2[:user].id], "actions")

      assert [%{extra_text: nil, type: "actions"}] =
               Moderation.list_reports(search: [reporter_id: user.id])
    end

    test "repeated targets only get one report", %{user: user, client: client} do
      {:ok, ctx2} = Tachyon.setup_client()
      target_id = ctx2[:user].id

      assert %{"status" => "success"} =
               Tachyon.report_user!(client, [target_id, target_id], "chat")

      assert [_only_one] = Moderation.list_reports(search: [reporter_id: user.id])
    end

    test "an over long message is truncated", %{user: user, client: client} do
      {:ok, ctx2} = Tachyon.setup_client()

      assert %{"status" => "success"} =
               Tachyon.report_user!(client, [ctx2[:user].id], "chat",
                 message: String.duplicate("a", 300)
               )

      assert [%{extra_text: extra_text}] =
               Moderation.list_reports(search: [reporter_id: user.id])

      assert extra_text == String.duplicate("a", 255)
    end

    test "one unknown target rejects the whole report", %{user: user, client: client} do
      {:ok, ctx2} = Tachyon.setup_client()

      assert %{"status" => "failed", "reason" => "unknown_user"} =
               Tachyon.report_user!(client, [ctx2[:user].id, 999_999_999], "chat")

      assert [] = Moderation.list_reports(search: [reporter_id: user.id])
    end

    test "target id that isn't a number", %{client: client} do
      assert %{"status" => "failed", "reason" => "unknown_user"} =
               Tachyon.report_user!(client, ["not-an-id"], "chat")
    end

    test "no targets", %{client: client} do
      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.report_user!(client, [], "chat")
    end

    test "cannot report yourself", %{user: user, client: client} do
      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.report_user!(client, [user.id], "chat")
    end

    test "unknown reason type", %{user: user, client: client} do
      {:ok, ctx2} = Tachyon.setup_client()

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.report_user!(client, [ctx2[:user].id], "vibes")

      assert [] = Moderation.list_reports(search: [reporter_id: user.id])
    end

    test "restricted from reporting", %{user: user, client: client} do
      {:ok, ctx2} = Tachyon.setup_client()

      {:ok, _updated} =
        Account.get_user(user.id) |> Account.script_update_user(%{restrictions: ["Reporting"]})

      assert %{"status" => "failed", "reason" => "unauthorized"} =
               Tachyon.report_user!(client, [ctx2[:user].id], "chat")

      assert [] = Moderation.list_reports(search: [reporter_id: user.id])
    end
  end

  describe "info" do
    test "works", %{user: user, client: client} do
      %{id: user_id, name: name} = user
      %{country: country} = Account.get_user_by_id(user_id)
      user_id = to_string(user_id)

      assert %{
               "data" => %{
                 "userId" => ^user_id,
                 "username" => ^name,
                 "displayName" => ^name,
                 "countryCode" => ^country
               }
             } = Tachyon.user_info!(client, user_id)
    end

    test "user doesn't exist", %{client: client} do
      assert %{"status" => "failed", "reason" => "unknown_user"} =
               Tachyon.user_info!(client, "999999999")
    end

    test "returns translated roles" do
      user =
        GeneralTestLib.make_user(%{
          "roles" => ["Verified", "Admin", "Contributor"]
        })

      %{client: client} = Tachyon.connect(user)

      resp = Tachyon.user_info!(client, to_string(user.id))
      assert MapSet.new(resp["data"]["roles"]) == MapSet.new(["admin", "contributor"])
    end
  end

  describe "self event" do
    test "sent after login" do
      user = GeneralTestLib.make_user(%{"roles" => ["Verified"]})
      %{client: client} = Tachyon.connect(user, swallow_first_event: false)

      {:ok,
       %{
         "commandId" => "user/self",
         "data" => %{"user" => userdata}
       }} = Tachyon.recv_message(client)

      assert userdata["userId"] == to_string(user.id)
      assert userdata["username"] == user.name
      assert userdata["displayName"] == user.name
      assert userdata["status"] == "menu"
      assert userdata["matchmaking"] == %{"state" => "no_matchmaking"}
    end

    test "sent when roles are updated", %{user: user, client: client} do
      :ok = Player.update_user_roles(user.id, ["Contributor"])

      assert %{"commandId" => "user/self", "data" => %{"user" => userdata}} =
               Tachyon.recv_message!(client)

      assert userdata["roles"] == ["contributor"]
      assert userdata["matchmaking"] == %{"state" => "no_matchmaking"}
    end

    test "filters out unmappable roles in tachyon messages" do
      user =
        GeneralTestLib.make_user(%{
          "roles" => ["Verified", "Contributor"]
        })

      %{client: client} = Tachyon.connect(user, swallow_first_event: false)

      {:ok, %{"data" => %{"user" => userdata}}} = Tachyon.recv_message(client)

      # Test that only Tachyon-compatible roles are sent
      # "Verified" filtered out
      assert userdata["roles"] == ["contributor"]
    end
  end

  describe "updates" do
    test "must pass valid user ids", %{client: client} do
      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.subscribe_updates!(client, ["invalid-user-id"])
    end

    test "must pass id for existing users", %{client: client} do
      # negative integer are valid int, but guaranteed to be invalid postgres
      # primary key, so guaranteed no user behind that
      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.subscribe_updates!(client, ["-87931"])
    end

    test "for offline user", %{client: client} do
      other_user =
        GeneralTestLib.make_user(%{"roles" => ["Verified"]})

      assert %{"status" => "success"} =
               Tachyon.subscribe_updates!(client, [to_string(other_user.id)])

      # subscribing should also be followed by an updated event to get the full state
      assert {:ok,
              %{
                "commandId" => "user/updated",
                "data" => %{"users" => [user_data]}
              }} =
               Tachyon.recv_message(client)

      assert user_data["userId"] == to_string(other_user.id)
      assert user_data["username"] == other_user.name
      assert user_data["displayName"] == other_user.name
      assert user_data["status"] == "offline"
    end

    test "for online user", %{client: client} do
      {:ok, ctx} = Tachyon.setup_client()
      other_user = ctx[:user]

      assert %{"status" => "success"} =
               Tachyon.subscribe_updates!(client, [to_string(other_user.id)])

      # subscribing should also be followed by an updated event to get the full state
      assert {:ok,
              %{
                "commandId" => "user/updated",
                "data" => %{"users" => [user_data]}
              }} =
               Tachyon.recv_message(client)

      assert user_data["userId"] == to_string(other_user.id)
      assert user_data["username"] == other_user.name
      assert user_data["status"] == "menu"
    end

    test "when target connects", %{client: client} do
      other_user =
        GeneralTestLib.make_user(%{"roles" => ["Verified"]})

      assert %{"status" => "success"} =
               Tachyon.subscribe_updates!(client, [to_string(other_user.id)])

      assert {:ok, %{"commandId" => "user/updated"}} = Tachyon.recv_message(client)
      Tachyon.connect(other_user)

      assert {:ok,
              %{
                "commandId" => "user/updated",
                "data" => %{"users" => [user_data]}
              }} =
               Tachyon.recv_message(client)

      assert user_data["userId"] == to_string(other_user.id)
      assert user_data["status"] == "menu"
    end

    test "when target disconnects", %{client: client} do
      {:ok, ctx} = Tachyon.setup_client()
      other_user = ctx[:user]

      assert %{"status" => "success"} =
               Tachyon.subscribe_updates!(client, [to_string(other_user.id)])

      # get the full state
      assert {:ok, %{"commandId" => "user/updated", "data" => ev_data}} =
               Tachyon.recv_message(client)

      assert hd(ev_data["users"])["status"] == "menu"

      Tachyon.disconnect!(ctx[:client])

      assert {:ok,
              %{
                "commandId" => "user/updated",
                "data" => %{"users" => [user_data]}
              }} =
               Tachyon.recv_message(client)

      assert user_data["userId"] == to_string(ctx[:user].id)
      assert user_data["status"] == "offline"
    end

    test "unsubscribe invalid id", %{client: client} do
      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.unsubscribe_updates!(client, ["invalid-user-id"])
    end

    test "unsubscribe", %{client: client} do
      {:ok, ctx} = Tachyon.setup_client()
      other_user = ctx[:user]

      assert %{"status" => "success"} =
               Tachyon.subscribe_updates!(client, [to_string(other_user.id)])

      # swallow the first update message
      Tachyon.recv_message!(client)

      assert %{"status" => "success"} =
               Tachyon.unsubscribe_updates!(client, [to_string(other_user.id)])

      Tachyon.disconnect!(ctx[:client])
      assert {:error, :timeout} = Tachyon.recv_message(client)
    end

    test "avoid duplicate subscription", %{client: client} do
      {:ok, ctx} = Tachyon.setup_client()
      other_user = ctx[:user]

      assert %{"status" => "success"} =
               Tachyon.subscribe_updates!(client, [to_string(other_user.id)])

      # get the full state
      assert {:ok, %{"commandId" => "user/updated", "data" => ev_data}} =
               Tachyon.recv_message(client)

      # subscribe again!
      assert %{"status" => "success"} =
               Tachyon.subscribe_updates!(client, [to_string(other_user.id)])

      # still get full state
      assert {:ok, %{"commandId" => "user/updated", "data" => ev_data2}} =
               Tachyon.recv_message(client)

      assert ev_data == ev_data2

      Tachyon.disconnect!(ctx[:client])

      # don't get duplicates
      assert {:ok, %{"commandId" => "user/updated"}} = Tachyon.recv_message(client)
      assert {:error, :timeout} == Tachyon.recv_message(client)
    end

    test "broadcasts translated roles" do
      user =
        GeneralTestLib.make_user(%{
          "roles" => ["Verified", "Moderator"]
        })

      %{client: client} = Tachyon.connect(user)

      # Subscribe to user updates
      Tachyon.subscribe_updates!(client, [to_string(user.id)])

      # Get the update event
      {:ok, %{"data" => %{"users" => [user_data]}}} = Tachyon.recv_message(client)
      assert user_data["roles"] == ["moderator"]
    end
  end
end
