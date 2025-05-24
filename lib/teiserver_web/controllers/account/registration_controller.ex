defmodule TeiserverWeb.Account.RegistrationController do
  use TeiserverWeb, :controller
  alias Teiserver.Account

  plug :registration_enabled?

  def new(conn, _params) do
    changeset = Account.change_user(%Account.User{})

    conn
    |> assign(:changeset, changeset)
    |> assign(:action, ~p"/register")
    |> render("new.html")
  end

  def create(conn, params) do
    case Account.register_user(Map.get(params, "user", %{}), :plain_password) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Account created")
        |> redirect(to: ~p"/login")

      {:error, changeset} ->
        changeset = Ecto.Changeset.delete_change(changeset, :password)

        conn
        |> assign(:changeset, changeset)
        |> assign(:action, ~p"/register")
        |> put_status(:bad_request)
        |> render("new.html")
    end
  end

  defp registration_enabled?(conn, _params) do
    if Account.can_register_with_web?() do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> render("disabled.html")
      |> halt()
    end
  end
end
