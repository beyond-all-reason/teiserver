defmodule CentralWeb.Account.SetupController do
  use CentralWeb, :controller
  alias Central.Account

  def setup(conn, %{"key" => key}) do
    true_key = Application.get_env(:central, Central.Setup)[:key]

    case key == true_key do
      false ->
        conn
        |> put_flash(:danger, "Error.")
        |> redirect(to: "/")

      true ->
        users = Central.Account.list_users()

        if users == [] do
          {:ok, group} = Account.create_group(%{
            name: "Root group",
            colour: "#AA0000",
            icon: "far fa-info",
            active: true,
            group_type: nil,
            data: %{},
            see_group: false,
            see_members: false,
            invite_members: false,
            self_add_members: false,
            super_group_id: nil
          })

          {:ok, user} = Account.create_user(%{
            name: "root",
            email: "root@localhost",
            password: true_key,
            permissions: ["admin.dev.developer"],
            admin_group_id: group.id,
            icon: "fas fa-power-off",
            colour: "#00AA00"
          })

          Account.create_group_membership(%{
            "group_id" => group.id,
            "user_id" => user.id,
            "admin" => true
          })

          conn
          |> put_flash(:success, "User created with email root@localhost and the password #{true_key}.")
          |> redirect(to: "/")
        else
          conn
          |> put_flash(:danger, "Error.")
          |> redirect(to: "/")
        end
    end
  end
end
