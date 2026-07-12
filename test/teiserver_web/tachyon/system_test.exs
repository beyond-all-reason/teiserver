defmodule TeiserverWeb.Tachyon.SystemTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.OAuthFixtures
  alias Teiserver.Support.Polling
  alias Teiserver.Support.Tachyon
  use TeiserverWeb.ConnCase

  describe "server stats" do
    defp setup_app(_context) do
      owner = GeneralTestLib.make_user(%{"roles" => ["Verified"]})

      app =
        OAuthFixtures.app_attrs(owner.id)
        |> Map.put(:uid, UUID.uuid4())
        |> OAuthFixtures.create_app()

      {:ok, app: app}
    end

    defp setup_user(app, name) do
      user = GeneralTestLib.make_user(%{"name" => name, "roles" => ["Verified"]})
      token = OAuthFixtures.token_attrs(user, app) |> OAuthFixtures.create_token()
      client = Tachyon.connect(token)
      {:ok, %{user: user, token: token, client: client}}
    end

    setup [:setup_app]

    test "works", %{app: app} do
      {:ok, %{client: client1}} = setup_user(app, "client1")
      {:ok, %{client: client2}} = setup_user(app, "client2")

      assert %{"data" => %{"userCount" => 2}} = Tachyon.server_stats!(client1)
      assert %{"data" => %{"userCount" => 2}} = Tachyon.server_stats!(client2)

      Tachyon.disconnect!(client2)

      Polling.poll_until(fn -> Tachyon.server_stats!(client1) end, fn data ->
        data["data"]["userCount"] == 1
      end)
    end
  end
end
