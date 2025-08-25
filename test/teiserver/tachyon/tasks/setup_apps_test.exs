defmodule Teiserver.Tachyon.Tasks.SetupAppsTest do
  use Teiserver.DataCase
  alias Teiserver.OAuth.{Application, ApplicationQueries}
  alias Teiserver.Tachyon.Tasks.SetupApps

  setup _context do
    user =
      Central.Helpers.GeneralTestLib.make_user(%{
        "email" => "root@localhost",
        "data" => %{"roles" => ["Verified"]}
      })

    # because all the f*ing queries are using caches, without a way to disable that
    on_exit(fn ->
      Teiserver.TeiserverTestLib.clear_cache(:users_lookup_id_with_email)
    end)

    {:ok, user: user}
  end

  describe "setup tachyon apps" do
    test "lobby app" do
      assert ApplicationQueries.get_application_by_uid("generic_lobby") == nil
      SetupApps.ensure_lobby_app()

      assert %Application{} = ApplicationQueries.get_application_by_uid("generic_lobby")
    end

    test "asset admin app" do
      assert ApplicationQueries.get_application_by_uid("asset_admin") == nil
      SetupApps.ensure_asset_admin_app()

      %Application{} = ApplicationQueries.get_application_by_uid("asset_admin")
    end

    test "user admin app" do
      assert ApplicationQueries.get_application_by_uid("user_admin") == nil
      SetupApps.ensure_user_admin_app()

      %Application{} = ApplicationQueries.get_application_by_uid("user_admin")
    end
  end
end
