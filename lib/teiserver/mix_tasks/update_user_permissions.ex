defmodule Mix.Tasks.Teiserver.UpdateUserPermissions do
  @moduledoc """
  If you make changes to role_lib.ex then run this task to update user permissions
  mix teiserver.update_user_permissions
  """

  use Mix.Task
  require Logger
  alias Teiserver.Account
  alias Teiserver.Repo
  alias Teiserver.Account.RoleLib

  def run(_args) do
    Application.ensure_all_started(:teiserver)
    user_ids = get_user_ids()

    Enum.each(user_ids, fn user_id ->
      user = Account.get_user!(user_id)
      roles = user.roles

      permissions =
        roles
        |> Enum.map(fn role_name ->
          role_def = RoleLib.role_data(role_name)
          [role_name | role_def.contains]
        end)
        |> List.flatten()
        |> Enum.uniq()

      user_params = %{
        "permissions" => permissions
      }

      Account.server_update_user(user, user_params)
    end)
  end

  defp get_user_ids() do
    query = """
      select id from account_users
    """

    results = Ecto.Adapters.SQL.query!(Repo, query, [])

    results.rows
    |> Enum.map(fn [userid] ->
      userid
    end)
  end
end
