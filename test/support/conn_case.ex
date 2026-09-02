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

  alias Ecto.Adapters.SQL.Sandbox
  alias Phoenix.ConnTest
  alias Teiserver.Config
  alias Teiserver.Support.Tachyon
  alias Teiserver.TeiserverTestLib

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Ecto.Adapters.SQL.Sandbox
      alias Phoenix.ConnTest
      alias Teiserver.Config
      alias Teiserver.Support.Tachyon
      alias Teiserver.TeiserverTestLib

      # Import conveniences for testing with connections
      import Plug.Conn
      import ConnTest
      import TeiserverWeb.ConnCase

      import Phoenix.LiveViewTest

      # The default endpoint for testing
      unquote(TeiserverWeb.verified_routes())
      @endpoint TeiserverWeb.Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Teiserver.Repo)
    TeiserverTestLib.clear_all_con_caches()
    Config.update_site_config("system.Use geoip", false)
    on_exit(&TeiserverTestLib.clear_all_con_caches/0)

    if !tags[:async] do
      Sandbox.mode(Teiserver.Repo, {:shared, self()})

      :ok =
        Supervisor.terminate_child(Teiserver.Supervisor, Config.SiteConfigTypes.Cache)

      {:ok, _pid} =
        Supervisor.restart_child(Teiserver.Supervisor, Config.SiteConfigTypes.Cache)
    end

    Tachyon.tachyon_case_setup(tags)
    {:ok, conn: ConnTest.build_conn()}
  end

  @doc """
  Given the HTML for a table, will convert that table into a map.

  E.g.
  table_to_map(~s(<table>
    <thead>
      <tr>
        <th>Name</th>
        <th>Email</th>
        <th>Role</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>Alice</td>
        <td>alice@example.com</td>
        <td>Admin</td>
      </tr>
      <tr>
        <td>Bob</td>
        <td>bob@example.com</td>
        <td>User</td>
      </tr>
    </tbody>
  </table>))

  Results in
  {:ok,
    %{
    rows: [
      %{"Email" => "alice@example.com", "Name" => "Alice", "Role" => "Admin"},
      %{"Email" => "bob@example.com", "Name" => "Bob", "Role" => "User"}
    ],
    headers: ["Name", "Email", "Role"]
  }}
  """
  def table_to_map(html) do
    with {:ok, document} <- Floki.parse_document(html),
         [table | _remainder] <- Floki.find(document, "table"),
         {:ok, headers} <- extract_headers(table),
         {:ok, rows} <- extract_rows(table, length(headers)) do
      result = %{
        headers: headers,
        rows: Enum.map(rows, &Map.new(Enum.zip(headers, &1)))
      }

      {:ok, result}
    else
      [] ->
        {:error, :no_table}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_headers(table) do
    headers =
      table
      |> Floki.find("thead tr:first-child th")
      |> Enum.map(&normalise_text/1)
      |> Enum.reject(&(&1 == ""))

    if headers == [] do
      {:error, :no_headers}
    else
      {:ok, headers}
    end
  end

  defp extract_rows(table, header_count) do
    rows =
      table
      |> Floki.find("tbody tr")
      |> Enum.map(fn row ->
        row
        |> Floki.find("td")
        |> Enum.map(&normalise_text/1)
      end)

    if Enum.all?(rows, &(length(&1) == header_count)) do
      {:ok, rows}
    else
      {:error, :row_column_count_mismatch}
    end
  end

  @doc """
  Given a mapped table, extract a row based on column/value combination
  """
  def extract_row(%{rows: rows} = _table, column, value) do
    rows
    |> Enum.find(fn row ->
      row[column] == value
    end)
  end

  @doc """
  Clean up the text of the element
  """
  def normalise_text(element) do
    element
    |> Floki.text()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end
end
