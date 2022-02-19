defmodule CentralWeb.Admin.CodeController do
  use CentralWeb, :controller

  alias Central.Account
  alias Central.Account.{Code, CodeLib}

  plug Bodyguard.Plug.Authorize,
    policy: Central.Account.Code,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "central_admin",
    sub_menu_active: "code"
  )

  plug :add_breadcrumb, name: 'Account', url: '/central'
  plug :add_breadcrumb, name: 'Codes', url: '/central/codes'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    codes =
      Account.list_codes(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim()
        ],
        preload: [:user],
        order_by: "Newest first"
      )

    conn
    |> assign(:codes, codes)
    |> render("index.html")
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    code =
      Account.get_code!(nil,
        search: [id: id]
      )

    {:ok, _code} = Account.delete_code(code)

    conn
    |> put_flash(:info, "Code deleted successfully.")
    |> redirect(to: Routes.admin_code_path(conn, :index))
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Account.change_code(%Code{expires: "24 hours"})

    conn
    |> assign(:changeset, changeset)
    |> assign(:code_types, CodeLib.code_types())
    |> add_breadcrumb(name: "New code", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"code" => code_params}) do
    code_params = Map.merge(code_params, %{
      "user_id" => conn.current_user.id
    })

    case Account.create_code(code_params) do
      {:ok, _code} ->
        conn
        |> put_flash(:info, "Code created successfully.")
        |> redirect(to: Routes.admin_code_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:code_types, CodeLib.code_types())
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec extend(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def extend(conn, %{"id" => id, "hours" => hours}) do
    code = Account.get_code!(nil, search: [id: id])
    new_expires = if Timex.compare(Timex.now(), code.expires) == 1 do
      # If it's 1 then the code is currently expired
      Timex.shift(Timex.now(), hours: hours |> String.to_integer)
    else
      Timex.shift(code.expires, hours: hours |> String.to_integer)
    end

    case Account.update_code(code, %{"expires" => new_expires}) do
      {:ok, _code} ->
        conn
        |> put_flash(:success, "Code expiry extended.")
        |> redirect(to: Routes.admin_code_path(conn, :index))
    end
  end
end
