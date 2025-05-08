defmodule TeiserverWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use TeiserverWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import TeiserverWeb.ConnCase

      alias TeiserverWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      unquote(TeiserverWeb.verified_routes())
      @endpoint TeiserverWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Teiserver.Repo)
    Teiserver.TeiserverTestLib.clear_all_con_caches()
    Teiserver.Config.update_site_config("system.Use geoip", false)
    on_exit(&Teiserver.TeiserverTestLib.clear_all_con_caches/0)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Teiserver.Repo, {:shared, self()})

      :ok =
        Supervisor.terminate_child(Teiserver.Supervisor, Teiserver.Config.SiteConfigTypes.Cache)

      {:ok, _pid} =
        Supervisor.restart_child(Teiserver.Supervisor, Teiserver.Config.SiteConfigTypes.Cache)
    end

    Teiserver.Support.Tachyon.tachyon_case_setup(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
