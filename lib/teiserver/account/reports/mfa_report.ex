defmodule Teiserver.Account.MFAReport do
  @moduledoc """
  A report listing users with heightened permissions who are not using MFA.
  """
  alias Ecto.Adapters.SQL
  alias Teiserver.Account.AuthLib
  alias Teiserver.Repo

  @spec icon() :: String.t()
  def icon, do: "fa-solid fa-key"

  @spec permissions() :: String.t()
  def permissions, do: "Moderator"

  @spec run(Plug.Conn.t(), map()) :: {nil, map()}
  def run(_conn, _params) do
    users = query_data()

    assigns = %{
      params: %{},
      users: users
    }

    {nil, assigns}
  end

  defp query_data do
    roles = AuthLib.mfa_roles()

    query = """
    SELECT
      users.id,
      users.name,
      users.last_login,
      users.roles
    FROM
      account_users AS users
    LEFT JOIN
      teiserver_account_user_totps AS totps
      ON totps.user_id = users.id
    WHERE
      users.roles && $1::varchar[]
      AND totps.user_id IS NULL -- Remove anybody with a TOTPS entry
    ORDER BY
      users.name ASC
    LIMIT 200;
    """

    case SQL.query(Repo, query, [roles]) do
      {:ok, results} ->
        results.rows
        |> Enum.map(fn [id, name, last_login, roles] ->
          %{
            id: id,
            name: name,
            last_login: last_login,
            roles: roles
          }
        end)

      {a, b} ->
        raise "ERR: #{inspect(a)}, #{inspect(b)}"
    end
  end
end
