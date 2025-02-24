defmodule TeiserverWeb.Tachyon.SystemTest do
  use TeiserverWeb.ConnCase
  alias Teiserver.Support.{Tachyon, Polling}
  alias Teiserver.OAuthFixtures

  describe "server stats" do
    defp setup_app(_context) do
      owner = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})

      app =
        OAuthFixtures.app_attrs(owner.id)
        |> Map.put(:uid, UUID.uuid4())
        |> OAuthFixtures.create_app()

      {:ok, app: app}
    end

    defp setup_user(app) do
      user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
      token = OAuthFixtures.token_attrs(user.id, app) |> OAuthFixtures.create_token()
      client = Tachyon.connect(token)
      {:ok, %{user: user, token: token, client: client}}
    end

    setup [:setup_app]

    test "works", %{app: app} do
      {:ok, %{client: client1}} = setup_user(app)
      {:ok, %{client: client2}} = setup_user(app)

      assert %{"data" => %{"userCount" => 2}} = Tachyon.server_stats!(client1)
      assert %{"data" => %{"userCount" => 2}} = Tachyon.server_stats!(client2)

      Tachyon.disconnect!(client2)

      Polling.poll_until(fn -> Tachyon.server_stats!(client1) end, fn data ->
        data["data"]["userCount"] == 1
      end)
    end
  end
end
