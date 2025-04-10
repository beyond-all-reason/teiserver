defmodule TeiserverWeb.Tachyon.PartyTest do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.Support.Tachyon

  describe "create" do
    setup [{Tachyon, :setup_client}]

    test "works", %{client: client} do
      assert %{"status" => "success"} = Tachyon.create_party!(client)
    end

    test "cannot join 2 parties", %{client: client} do
      assert %{"status" => "success"} = Tachyon.create_party!(client)

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.create_party!(client)
    end
  end

  describe "self event" do
    test "has the correct data" do
      user = Tachyon.create_user()
      %{client: client} = Tachyon.connect(user, swallow_first_event: false)
      %{"commandId" => "user/self", "data" => %{"user" => event}} = Tachyon.recv_message!(client)
      assert %{"party" => nil} = event
    end

    test "works after reconnection" do
      user = Tachyon.create_user()
      %{client: client} = Tachyon.connect(user)

      assert %{"status" => "success", "data" => %{"partyId" => party_id}} =
               Tachyon.create_party!(client)

      Tachyon.abrupt_disconnect!(client)
      %{client: client} = Tachyon.connect(user, swallow_first_event: false)

      %{"commandId" => "user/self", "data" => %{"user" => event}} = Tachyon.recv_message!(client)
      assert %{"party" => %{"id" => ^party_id}} = event
    end
  end
end
