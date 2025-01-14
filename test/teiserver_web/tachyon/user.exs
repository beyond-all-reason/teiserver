defmodule Teiserver.Tachyon.UserTest do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.Support.Tachyon

  describe "updated" do
    test "sent after login" do
      user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})

      %{client: client} = Tachyon.connect(user, swallow_first_event: false)

      expected_user_id = to_string(user.id)

      {:ok,
       %{
         "commandId" => "user/updated",
         "data" => %{
           "users" => [
             %{"userId" => recv_user_id}
           ]
         }
       }} = Tachyon.recv_message(client)

      assert recv_user_id == expected_user_id
    end
  end
end
