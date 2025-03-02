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
end
