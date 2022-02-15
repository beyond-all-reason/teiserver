defmodule CentralWeb.Account.RegistrationController do
  use CentralWeb, :controller

  alias Central.Account
  alias Central.Account.User

  plug AssignPlug,
    sidemenu_active: "account"

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, params) do
    config_setting = Application.get_env(:central, Central)[:user_registrations]

    {allowed, reason} = cond do
      config_setting == :allowed ->
        {true, nil}

      config_setting == :disabled ->
        {false, "disabled"}

      config_setting == :link_only ->
        code = Account.get_code(params["code"] || "!no_code!")

        cond do
          code == nil ->
            {false, "no_code"}

          code.purpose != "user_registration" ->
            {false, "invalid_code"}

          Timex.compare(Timex.now(), code.expires) == 1 ->
            {false, "expired_code"}

          true ->
            {true, nil}
        end

      true ->
        {false, "disabled"}
    end

    if allowed do
      changeset = Account.change_user(%User{})

      conn
      |> assign(:code, params["code"])
      |> assign(:changeset, changeset)
      |> put_layout("empty.html")
      |> render("new.html")
    else
      conn
      |> assign(:reason, reason)
      |> put_layout("empty.html")
      |> render("invalid.html")
    end
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    user_params = Account.merge_default_params(user_params)
    config_setting = Application.get_env(:central, Central)[:user_registrations]

    {allowed, reason} = cond do
      config_setting == :allowed ->
        {true, nil}

      config_setting == :disabled ->
        {false, "disabled"}

      config_setting == :link_only ->
        code = Account.get_code(user_params["code"] || "!no_code!")

        cond do
          code == nil ->
            {false, "no_code"}

          code.purpose != "user_registration" ->
            {false, "invalid_code"}

          Timex.compare(Timex.now(), code.expires) == 1 ->
            {false, "expired_code"}

          true ->
            {true, nil}
        end

      true ->
        {false, "disabled"}
    end

    if allowed do
      case Account.self_create_user(user_params) do
        {:ok, user} ->
          case Account.get_code(user_params["code"]) do
            nil ->
              :ok
            code ->
              add_audit_log(conn, "user_registration", %{
                code_value: code.value,
                code_creator: code.user_id
              })
          end

          conn
          |> put_flash(:info, "User created successfully.")
          |> redirect(to: "/")

        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> assign(:code, user_params["code"])
          |> assign(:changeset, changeset)
          |> put_layout("empty.html")
          |> render("new.html")
      end
    else
      conn
      |> assign(:reason, reason)
      |> put_layout("empty.html")
      |> render("invalid.html")
    end
  end

  @spec edit_details(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit_details(conn, _params) do
    user = Account.get_user!(conn.user_id)
    changeset = Account.change_user(user)

    conn
    |> assign(:changeset, changeset)
    |> assign(:user, user)
    |> render("edit_details.html")
  end

  @spec edit_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit_password(conn, _params) do
    user = Account.get_user!(conn.user_id)
    changeset = Account.change_user(user)

    conn
    |> assign(:changeset, changeset)
    |> assign(:user, user)
    |> render("edit_password.html")
  end

  @spec update_details(Plug.Conn.t(), map()) :: Plug.Conn.t()
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

  @spec update_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_password(conn, %{"user" => user_params}) do
    user = Account.get_user!(conn.user_id)

    case Account.update_user(user, user_params, :password) do
      {:ok, _user} ->
        # User password updated
        Teiserver.User.set_new_spring_password(user.id, user_params["password"])

        conn
        |> put_flash(:info, "Account password updated successfully.")
        |> redirect(to: Routes.account_general_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit_password.html", user: user, changeset: changeset)
    end
  end
end
