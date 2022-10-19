defmodule TeiserverWeb.Admin.AutomodActionController do
  use CentralWeb, :controller

  alias Central.Logging
  alias Teiserver.{Account}
  alias Teiserver.Account.{AutomodAction, AutomodActionLib}

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.AutomodAction,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "teiserver_admin",
    sub_menu_active: "automod_action"
  )

  plug :add_breadcrumb, name: 'Account', url: '/teiserver'
  plug :add_breadcrumb, name: 'AutomodActions', url: '/teiserver/automod_actions'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, _params) do
    automod_actions = Account.list_automod_actions(
      search: [
        # basic_search: Map.get(params, "s", "") |> String.trim,
      ],
      preload: [:user, :added_by],
      order_by: "Newest first"
    )

    conn
    |> assign(:automod_actions, automod_actions)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    automod_action = Account.get_automod_action!(id, [
      preload: [:user, :added_by]
    ])

    logs = Logging.list_audit_logs(
      search: [
        actions: [
            "Teiserver:Updated automod action",
            "Teiserver:Automod action enacted"
          ],
        details_equal: {"automod_action_id", automod_action.id |> to_string}
      ],
      joins: [:user],
      order_by: "Newest first"
    )

    targets = logs
      |> Enum.map(fn log -> log.details["target_user_id"] end)
      |> Enum.reject(&(&1 == nil))
      |> Map.new(fn userid ->
        {userid, Account.get_username(userid)}
      end)

    automod_action
      |> AutomodActionLib.make_favourite
      |> insert_recently(conn)

    conn
      |> assign(:automod_action, automod_action)
      |> assign(:logs, logs)
      |> assign(:targets, targets)
      |> add_breadcrumb(name: "Show: #{automod_action.user.name}", url: conn.request_path)
      |> render("show.html")
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Account.change_automod_action(%AutomodAction{})

    conn
      |> assign(:changeset, changeset)
      |> add_breadcrumb(name: "New automod_action", url: conn.request_path)
      |> render("new.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"automod_action" => automod_action_params}) do
    automod_action_params = Map.merge(automod_action_params, %{
      "added_by_id" => conn.current_user.id
    })

    case Account.create_automod_action(automod_action_params) do
      {:ok, _automod_action} ->
        conn
        |> put_flash(:info, "AutomodAction created successfully.")
        |> redirect(to: Routes.ts_admin_automod_action_path(conn, :index))

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_flash(:danger, "Invalid Automod-Action changeset")
        |> redirect(to: Routes.ts_admin_user_path(conn, :automod_action_form, automod_action_params["user_id"]))
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    automod_action = Account.get_automod_action!(id,
      preload: [:user, :added_by]
    )

    changeset = Account.change_automod_action(automod_action)

    conn
      |> assign(:automod_action, automod_action)
      |> assign(:changeset, changeset)
      |> add_breadcrumb(name: "Edit: #{automod_action.user.name}", url: conn.request_path)
      |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "automod_action" => automod_action_params}) do
    automod_action = Account.get_automod_action!(id)

    case Account.update_automod_action(automod_action, automod_action_params) do
      {:ok, _automod_action} ->
        conn
        |> put_flash(:info, "AutomodAction updated successfully.")
        |> redirect(to: Routes.ts_admin_automod_action_path(conn, :index))
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:automod_action, automod_action)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    automod_action = Account.get_automod_action!(id)

    automod_action
    |> AutomodActionLib.make_favourite
    |> remove_recently(conn)

    {:ok, _automod_action} = Account.delete_automod_action(automod_action)

    conn
    |> put_flash(:info, "AutomodAction deleted successfully.")
    |> redirect(to: Routes.ts_admin_automod_action_path(conn, :index))
  end

  @spec enable(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def enable(conn, %{"id" => id}) do
    automod_action = Account.get_automod_action!(id)

    add_audit_log(conn, "Teiserver:Updated automod action", %{
      automod_action_id: automod_action.id,
      change: "Enabled"
    })

    case Account.update_automod_action(automod_action, %{"enabled" => true}) do
      {:ok, _automod_action} ->
        conn
        |> put_flash(:info, "Automod Action enabled successfully.")
        |> redirect(to: Routes.ts_admin_automod_action_path(conn, :show, id))
    end
  end

  @spec disable(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def disable(conn, %{"id" => id}) do
    automod_action = Account.get_automod_action!(id)

    add_audit_log(conn, "Teiserver:Updated automod action", %{
      automod_action_id: automod_action.id,
      change: "Disabled"
    })

    case Account.update_automod_action(automod_action, %{"enabled" => false}) do
      {:ok, _automod_action} ->
        conn
        |> put_flash(:info, "Automod Action disabled successfully.")
        |> redirect(to: Routes.ts_admin_automod_action_path(conn, :show, id))
    end
  end
end
