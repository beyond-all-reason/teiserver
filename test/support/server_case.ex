defmodule Teiserver.ServerCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Teiserver.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  alias Ecto.Changeset
  alias Teiserver.Config
  alias Teiserver.DataCase
  alias Teiserver.Support.Tachyon
  alias Teiserver.TeiserverTestLib

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Ecto.Changeset
      alias Teiserver.Config
      alias Teiserver.DataCase
      alias Teiserver.Repo
      alias Teiserver.Support.Tachyon
      alias Teiserver.TeiserverTestLib

      import Changeset
      import Ecto.Query
      import DataCase
    end
  end

  setup tags do
    # clearing the caches *before* shouldn't be needed, but until we clean
    # all the tests that have side effects, this is a stopgap measure to avoid
    # more false failures.
    TeiserverTestLib.clear_all_con_caches()
    Tachyon.tachyon_case_setup(tags)
    DataCase.setup_sandbox(tags)
    Config.update_site_config("system.Use geoip", false)

    on_exit(&TeiserverTestLib.clear_all_con_caches/0)
    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _full_match, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
