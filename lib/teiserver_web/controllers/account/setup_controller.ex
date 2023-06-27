defmodule TeiserverWeb.Account.SetupController do
  use CentralWeb, :controller
  alias Central.Account

  def setup(conn, %{"key" => key}) do
    true_key = Application.get_env(:central, Central.Setup)[:key]

    cond do
      key != true_key ->
        conn
        |> put_flash(:danger, "Key error.")
        |> redirect(to: "/")

      true_key == "" or true_key == nil ->
        conn
        |> put_flash(:danger, "Please ensure there is a setup key.")
        |> redirect(to: "/")

      true ->
        users = Central.Account.list_users(search: [email: "root@localhost"])

        if users == [] do
          {:ok, _user} =
            Account.create_user(%{
              name: "root",
              email: "root@localhost",
              password: true_key,
              permissions: ["admin.dev.developer"],
              icon: "fa-solid fa-power-off",
              colour: "#00AA00"
            })

          conn
          |> put_flash(
            :success,
            "User created with email root@localhost and the password #{true_key}."
          )
          |> redirect(to: "/")
        else
          conn
          |> put_flash(:danger, "Error.")
          |> redirect(to: "/")
        end
    end
  end
end
