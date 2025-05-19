defmodule TeiserverWeb.Tachyon.UserTest do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.Support.Tachyon

  describe "info" do
    setup [{Tachyon, :setup_client}]

    test "works", %{user: user, client: client} do
      %{id: user_id, name: name, clan_id: clan_id} = user
      %{country: country} = Teiserver.Account.get_user_by_id(user_id)
      user_id = to_string(user_id)

      user_id = to_string(user_id)

      assert %{
               "data" => %{
                 "userId" => ^user_id,
                 "username" => ^name,
                 "displayName" => ^name,
                 "clanId" => ^clan_id,
                 "countryCode" => ^country
               }
             } = Tachyon.user_info!(client, user_id)
    end

    test "user doesn't exist", %{client: client} do
      assert %{"status" => "failed", "reason" => "unknown_user"} =
               Tachyon.user_info!(client, "999999999")
    end
  end

  describe "self event" do
    test "sent after login" do
      user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
      %{client: client} = Tachyon.connect(user, swallow_first_event: false)

      {:ok,
       %{
         "commandId" => "user/self",
         "data" => %{"user" => userdata}
       }} = Tachyon.recv_message(client)

      assert userdata["userId"] == to_string(user.id)
      assert userdata["username"] == user.name
      assert userdata["clanId"] == user.clan_id
      assert userdata["status"] == "menu"
    end
  end

  describe "updates" do
    setup [{Tachyon, :setup_client}]

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
        Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})

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
      assert user_data["clanId"] == other_user.clan_id
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
      assert user_data["clanId"] == other_user.clan_id
      assert user_data["status"] == "menu"
    end

    test "when target connects", %{client: client} do
      other_user =
        Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})

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
  end
end
