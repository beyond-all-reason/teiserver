defmodule Teiserver.Tachyon.UserTest do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.Support.Tachyon

  describe "updated" do
    test "sent after login" do
      user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})

      %{client: client} = Tachyon.connect(user, swallow_first_event: false)

      {:ok,
       %{
         "commandId" => "user/updated",
         "data" => %{
           "users" => [userdata]
         }
       }} = Tachyon.recv_message(client)

      assert userdata["userId"] == to_string(user.id)
      assert userdata["username"] == user.name
      assert userdata["clanId"] == user.clan_id
      assert userdata["status"] == "menu"
    end
  end
end
