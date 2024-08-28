defmodule TeiserverWeb.Admin.OAuthApplicationController do
  use TeiserverWeb, :controller

  alias Teiserver.OAuth.{Application, ApplicationQueries}
  alias Teiserver.{OAuth, Account}

  plug Bodyguard.Plug.Authorize,
    # The policy should be Admin or something fairly high. But while we're
    # developping the new lobby, it's easier if this is allowed for any
    # contributors
    policy: Teiserver.Staff,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: "Admin", url: "/teiserver/admin"
  plug :add_breadcrumb, name: "OAuth Applications", url: "/teiserver/admin/oauth_application"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    applications = ApplicationQueries.list_applications()
    stats = ApplicationQueries.get_stats(Enum.map(applications, fn app -> app.id end))

    conn
    |> assign(:page_title, "BAR - oauth apps")
    |> render("index.html", app_and_stats: Enum.zip(applications, stats))
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    defaults = %{
      name: "Generic Lobby Client",
      uid: "generic_lobby",
      scopes: Application.allowed_scopes(),
      owner_email: Map.get(conn.assigns[:current_user], :email)
    }

    changeset = OAuth.change_application(%Application{}, defaults)

    conn
    |> assign(:page_title, "BAR - new OAuth app")
    |> render("new.html", changeset: changeset)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"application" => app}) do
    app = form_to_app(app)

    case OAuth.create_application(app) do
      {:ok, %Application{} = app} ->
        conn
        |> put_flash(:info, "Application created")
        |> redirect(to: ~p"/teiserver/admin/oauth_application/#{app}")

      {:error, changeset} ->
        # Because the changeset expects owner_id but the form is using owner_email
        # need to shuffle around the errors if any
        changeset = fill_email_error(changeset)

        conn
        |> put_status(400)
        |> assign(:page_title, "BAR - new OAuth app")
        |> render("new.html", changeset: changeset)
    end
  end

  def create(conn, _),
    do:
      conn
      |> put_status(400)
      |> assign(:page_title, "BAR - new OAuth app")
      |> render("new.html", changeset: Application.changeset(%Application{}, %{}))

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, assigns) do
    case ApplicationQueries.get_application_by_id(Map.get(assigns, "id")) do
      %Application{} = app ->
        render_show(conn, app)

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, assigns) do
    case ApplicationQueries.get_application_by_id(Map.get(assigns, "id")) do
      %Application{} = app ->
        changeset = OAuth.change_application(Map.put(app, :owner_email, app.owner.email))

        conn
        |> assign(:page_title, "BAR - edit oauth app #{app.name}")
        |> render("edit.html", app: app, changeset: changeset)

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"application" => app_params} = assigns) do
    case ApplicationQueries.get_application_by_id(Map.get(assigns, "id")) do
      %Application{} = app ->
        attrs = form_to_app(app_params) |> Map.drop(["scopes"])

        case OAuth.update_application(app, attrs) do
          {:ok, app} ->
            conn
            |> put_flash(:info, "Application updated")
            |> render_show(app)

          {:error, changeset} ->
            changeset = fill_email_error(changeset)

            conn
            |> put_status(400)
            |> render("edit.html", app: app, changeset: changeset)
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, assigns) do
    case ApplicationQueries.get_application_by_id(Map.get(assigns, "id")) do
      %Application{} = app ->
        case OAuth.delete_application(app) do
          :ok ->
            conn
            |> put_flash(:info, "Deleted!")
            |> redirect(to: ~p"/teiserver/admin/oauth_application")

          {:error, err} ->
            conn
            |> put_flash(:danger, inspect(err))
            |> redirect(to: ~p"/teiserver/admin/oauth_application/#{app.id}")
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  defp render_show(conn, app) do
    [stats] = ApplicationQueries.get_stats(app.id)

    conn
    |> assign(:page_title, "BAR - oauth app #{app.name}")
    |> render("show.html", app: app, stats: stats)
  end

  # split the comma separated fields and map emails to users
  defp form_to_app(params) do
    user_id = Map.get(Account.get_user_by_email(params["owner_email"]) || %{}, :id)

    params
    |> split_string_key("scopes")
    |> split_string_key("redirect_uris")
    |> then(fn m -> if user_id, do: Map.put(m, "owner_id", user_id), else: m end)
  end

  defp fill_email_error(changeset) do
    if Map.has_key?(changeset.data, "owner_id") and is_nil(Map.get(changeset.data, "owner_id")) do
      Ecto.Changeset.add_error(
        changeset,
        :owner_email,
        "No user found for email #{Map.get(changeset.data, "owner_email")}"
      )
    else
      changeset
    end
  end

  # A version of Map.update that doesn't touch the map if key is not present
  defp split_string_key(m, key) do
    case m do
      %{^key => value} when is_binary(value) ->
        Map.put(m, key, String.split(value, ",", trim: true) |> Enum.map(&String.trim/1))

      _ ->
        m
    end
  end
end
