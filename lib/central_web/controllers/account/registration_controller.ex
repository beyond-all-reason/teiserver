defmodule CentralWeb.Account.RegistrationController do
  use CentralWeb, :controller

  alias Central.Account
  alias Central.Account.User

  plug AssignPlug,
    sidemenu_active: "account"

  def new(conn, _params) do
    changeset = Account.change_user(%User{})

    conn
    |> assign(:changeset, changeset)
    |> put_layout("general.html")
    |> render("new.html")
  end

  def create(conn, %{"user" => user_params}) do
    user_params = Account.merge_default_params(user_params)

    case Account.self_create_user(user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: "/")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> put_layout("general.html")
        |> render("new.html")
    end
  end

  def edit_details(conn, _params) do
    user = Account.get_user!(conn.user_id)
    changeset = Account.change_user(user)

    conn
    |> assign(:changeset, changeset)
    |> assign(:user, user)
    |> render("edit_details.html")
  end

  def edit_password(conn, _params) do
    user = Account.get_user!(conn.user_id)
    changeset = Account.change_user(user)

    conn
    |> assign(:changeset, changeset)
    |> assign(:user, user)
    |> render("edit_password.html")
  end

  def update_details(conn, %{"user" => user_params}) do
    user = Account.get_user!(conn.user_id)
    user_params = Map.put(user_params, "password", user_params["password_confirmation"])

    case Account.update_user(user, user_params, :user_form) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Account details updated successfully.")
        |> redirect(to: Routes.account_general_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit_details.html", user: user, changeset: changeset)
    end
  end

  def update_password(conn, %{"user" => user_params}) do
    user = Account.get_user!(conn.user_id)

    case Account.update_user(user, user_params, :password) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Account password updated successfully.")
        |> redirect(to: Routes.account_general_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit_password.html", user: user, changeset: changeset)
    end
  end
end
