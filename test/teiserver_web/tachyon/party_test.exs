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
end
