defmodule TeiserverWeb.Admin.UserController do
  use CentralWeb, :controller

  alias Teiserver.Account
  alias Central.Account.User
  alias Teiserver.Account.UserLib
  alias Central.Account.GroupLib
  import Teiserver.User, only: [bar_user_group_id: 0]
  alias Central.Helpers.TimexHelper

  plug(AssignPlug,
    sidemenu_active: ["teiserver", "teiserver_admin"]
  )

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.Auth,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}
  )

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin')
  plug(:add_breadcrumb, name: 'Users', url: '/teiserver/admin/user')

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    users =
      Account.list_users(
        search: [
          admin_group: conn,
          simple_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Name (A-Z)",
        limit: 50
      )

    conn
    |> assign(:users, users)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    user = Account.get_user!(id)

    case Central.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        user
        |> UserLib.make_favourite()
        |> insert_recently(conn)

        conn
        |> assign(:user, user)
        |> add_breadcrumb(name: "Show: #{user.name}", url: conn.request_path)
        |> render("show.html")

      _ ->
        conn
        |> put_flash(:warning, "Unable to access this user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end

  @spec new(Plug.Conn.t(), map) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset =
      Account.change_user(%User{
        icon: "fas fa-user",
        colour: "#AA0000"
      })

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New user", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    user_params =
      Map.merge(user_params, %{
        "admin_group_id" => bar_user_group_id(),
        "password" => "pass",
        "data" => %{
          "rank" => 1,
          "country" => "",
          "friends" => [],
          "friend_requests" => [],
          "ignored" => [],
          "bot" => user_params["bot"] == "true",
          "moderator" => user_params["moderator"] == "true",
          "verified" => user_params["verified"] == "true",
          "password_hash" => "X03MO1qnZdYdgyfeuILPmQ=="
        }
      })

    case Account.create_user(user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  @spec edit(Plug.Conn.t(), map) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    user = Account.get_user!(id)

    case Central.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        changeset = Account.change_user(user)

        conn
        |> assign(:user, user)
        |> assign(:changeset, changeset)
        |> assign(:groups, GroupLib.dropdown(conn))
        |> add_breadcrumb(name: "Edit: #{user.name}", url: conn.request_path)
        |> render("edit.html")

      _ ->
        conn
        |> put_flash(:warning, "Unable to access this user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Account.get_user!(id)

    data =
      Map.merge(user.data || %{}, %{
        "bot" => user_params["bot"] == "true",
        "moderator" => user_params["moderator"] == "true",
        "verified" => user_params["verified"] == "true"
      })

    user_params = Map.put(user_params, "data", data)

    case Central.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        case Account.update_user(user, user_params) do
          {:ok, _user} ->
            conn
            |> put_flash(:info, "User updated successfully.")
            |> redirect(to: Routes.ts_admin_user_path(conn, :index))

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, "edit.html", user: user, changeset: changeset)
        end

      _ ->
        conn
        |> put_flash(:warning, "Unable to access this user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end

  @spec reset_password(Plug.Conn.t(), map) :: Plug.Conn.t()
  def reset_password(conn, %{"id" => id}) do
    user = Account.get_user!(id)

    case Central.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        {plain_password, encrypted_password} = Teiserver.User.generate_new_password()

        data =
          Map.merge(user.data || %{}, %{
            "password_hash" => encrypted_password
          })

        user_params = %{"data" => data}

        case Account.update_user(user, user_params) do
          {:ok, _user} ->
            conn
            |> put_flash(:info, "Password changed to '#{plain_password}'.")
            |> redirect(to: Routes.ts_admin_user_path(conn, :show, user))

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, "edit.html", user: user, changeset: changeset)
        end

      _ ->
        conn
        |> put_flash(:warning, "Unable to access this user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end

  @spec perform_action(Plug.Conn.t(), map) :: Plug.Conn.t()
  def perform_action(conn, %{"id" => id, "action" => action} = params) do
    user = Account.get_user!(id)

    case Central.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        result = case action do
          "permanent_ban" ->
            {:ok, %{"banned" => true}}

          "temporary_ban" ->
            case HumanTime.relative(params["until"]) do
              {:ok, v} ->
                {:ok, %{"banned_until" => TimexHelper.date_to_str(v, :ymd_hms)}}

              {:error, _} ->
                {:error, "Unable to understand date"}
            end
        end

        case result do
          {:ok, new_data} ->
            user_params = %{"data" => Map.merge(user.data || %{}, new_data)}
            case Account.update_user(user, user_params) do
              {:ok, _user} ->
                conn
                |> put_flash(:info, "Action performed.")
                |> redirect(to: Routes.ts_admin_user_path(conn, :show, user))

              {:error, %Ecto.Changeset{} = changeset} ->
                render(conn, "edit.html", user: user, changeset: changeset)
            end

          {:error, msg} ->
            conn
            |> put_flash(:warning, "There was an error: #{msg}")
            |> redirect(to: Routes.ts_admin_user_path(conn, :show, user))
        end


      _ ->
        conn
        |> put_flash(:warning, "Unable to access this user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end
end
