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

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Teiserver.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Teiserver.DataCase
    end
  end

  setup tags do
    # clearing the caches *before* shouldn't be needed, but until we clean
    # all the tests that have side effects, this is a stopgap measure to avoid
    # more false failures.
    Teiserver.TeiserverTestLib.clear_all_con_caches()
    Teiserver.DataCase.setup_sandbox(tags)
    Teiserver.Config.update_site_config("system.Use geoip", false)

    unless tags[:async] do
      ExUnit.Callbacks.start_supervised!(Teiserver.Tachyon.System)
    end

    on_exit(&Teiserver.TeiserverTestLib.clear_all_con_caches/0)
    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
