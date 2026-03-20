defmodule Teiserver.Tachyon.Tasks.SetupAppsTest do
  alias Central.Helpers.GeneralTestLib
  alias Teiserver.OAuth.Application
  alias Teiserver.OAuth.ApplicationQueries
  alias Teiserver.Tachyon.Tasks.SetupApps
  alias Teiserver.TeiserverTestLib
  use Teiserver.DataCase

  setup _context do
    user =
      GeneralTestLib.make_user(%{
        "email" => "root@localhost",
        "roles" => ["Verified"]
      })

    # because all the f*ing queries are using caches, without a way to disable that
    on_exit(fn ->
      TeiserverTestLib.clear_cache(:users_lookup_id_with_email)
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
