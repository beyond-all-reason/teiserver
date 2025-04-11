defmodule TeiserverWeb.Tachyon.PartyTest do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.Support.Tachyon
  alias Teiserver.Support.Polling

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

  describe "leave" do
    setup [{Tachyon, :setup_client}]

    test "must be in party", %{client: client} do
      assert %{"status" => "failed", "reason" => "invalid_request"} = Tachyon.leave_party!(client)
    end

    test "can leave party", %{client: client} = ctx do
      {:ok, party_id: party_id} = setup_party(ctx)
      assert %{"status" => "success"} = Tachyon.leave_party!(client)
      Polling.poll_until_nil(fn -> Teiserver.Party.lookup(party_id) end)
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

  defp setup_party(%{client: client}), do: setup_party(client)

  defp setup_party(client) do
    assert %{"status" => "success", "data" => %{"partyId" => party_id}} =
             Tachyon.create_party!(client)

    {:ok, party_id: party_id}
  end
end
