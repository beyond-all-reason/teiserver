defmodule TeiserverWeb.Admin.AutohostController do
  @moduledoc """
  management of autohosts and their credentials
  """

  use TeiserverWeb, :controller

  alias Teiserver.{Autohost, AutohostQueries, OAuth}
  alias Teiserver.OAuth.{ApplicationQueries, CredentialQueries}

  plug Bodyguard.Plug.Authorize,
    # The policy should be Admin or something fairly high. But while we're
    # developping the new lobby, it's easier if this is allowed for any
    # contributors
    policy: Teiserver.Staff,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: "Admin", url: "/teiserver/admin"
  plug :add_breadcrumb, name: "Autohosts", url: "/teiserver/admin/autohost"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    autohosts = AutohostQueries.list_autohosts()
    cred_counts = CredentialQueries.count_per_autohosts(Enum.map(autohosts, fn a -> a.id end))

    conn
    |> render("index.html", autohosts: autohosts, cred_counts: cred_counts)
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Autohost.change_autohost(%Autohost.Autohost{})

    conn
    |> assign(:page_title, "")
    |> render("new.html", changeset: changeset)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"autohost" => attrs}) do
    case Autohost.create_autohost(attrs) do
      {:ok, %Autohost.Autohost{} = autohost} ->
        conn
        |> put_flash(:info, "Autohost created")
        |> redirect(to: ~p"/teiserver/admin/autohost/#{autohost.id}")

      {:error, changeset} ->
        conn
        |> assign(:page_title, "BAR - new autohost")
        |> put_status(400)
        |> render("new.html", changeset: changeset)
    end
  end

  def create(conn, _),
    do:
      conn
      |> put_status(400)
      |> assign(:page_title, "BAR - new autohost")
      |> render("new.html", changeset: Autohost.Autohost.changeset(%Autohost.Autohost{}, %{}))

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, assigns) do
    case Autohost.get_by_id(Map.get(assigns, "id")) do
      %Autohost.Autohost{} = autohost ->
        render_show(conn, autohost)

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, assigns) do
    case Autohost.get_by_id(Map.get(assigns, "id")) do
      %Autohost.Autohost{} = autohost ->
        changeset = Autohost.change_autohost(autohost)

        conn
        |> assign(:page_title, "BAR - edit autohost #{autohost.name}")
        |> render("edit.html", autohost: autohost, changeset: changeset)

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"autohost" => params} = assigns) do
    case Autohost.get_by_id(Map.get(assigns, "id")) do
      %Autohost.Autohost{} = autohost ->
        case Autohost.update_autohost(autohost, params) do
          {:ok, autohost} ->
            conn
            |> put_flash(:info, "Autohost updated")
            |> render_show(autohost)

          {:error, changeset} ->
            conn
            |> put_status(400)
            |> render(:edit, autohost: autohost, changeset: changeset)
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  def update(conn, _) do
    conn
    |> put_status(:not_found)
    |> render("not_found.html")
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, assigns) do
    case Autohost.get_by_id(Map.get(assigns, "id")) do
      %Autohost.Autohost{} = autohost ->
        case Autohost.delete(autohost) do
          :ok ->
            conn
            |> put_flash(:info, "Deleted!")
            |> redirect(to: ~p"/teiserver/admin/autohost")

          {:error, err} ->
            conn
            |> put_flash(:danger, inspect(err))
            |> redirect(to: ~p"/teiserver/admin/autohost/#{autohost.id}")
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec create_credential(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_credential(conn, assigns) do
    with autohost when not is_nil(autohost) <- Autohost.get_by_id(Map.get(assigns, "id")),
         app when not is_nil(app) <-
           ApplicationQueries.get_application_by_id(Map.get(assigns, "application")) do
      client_id = UUID.uuid4()
      secret = Base.hex_encode32(:crypto.strong_rand_bytes(32))

      case OAuth.create_credentials(app, autohost, client_id, secret) do
        {:ok, _cred} ->
          conn
          |> put_flash(:info, "credential created")
          |> Plug.Conn.put_resp_cookie("client_secret", secret, sign: true, max_age: 60)
          |> redirect(to: ~p"/teiserver/admin/autohost/#{autohost.id}")

        {:error, err} ->
          conn
          |> put_flash(:danger, inspect(err))
          |> render_show(autohost)
      end
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec delete_credential(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete_credential(conn, assigns) do
    with autohost when not is_nil(autohost) <- Autohost.get_by_id(Map.get(assigns, "id")),
         cred when not is_nil(cred) <-
           CredentialQueries.get_credential_by_id(Map.get(assigns, "cred_id")) do
      if cred.autohost_id != autohost.id do
        conn
        |> put_status(:bad_request)
        |> put_flash(:danger, "credential doesn't match autohost")
        |> render_show(autohost)
      else
        case OAuth.delete_credential(cred) do
          :ok ->
            conn
            |> put_flash(:info, "credential deleted")
            |> redirect(to: ~p"/teiserver/admin/autohost/#{autohost.id}")

          {:error, err} ->
            conn
            |> put_flash(:danger, inspect(err))
            |> render_show(autohost)
        end
      end
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  defp render_show(conn, autohost) do
    applications = ApplicationQueries.list_applications()
    credentials = CredentialQueries.for_autohost(autohost)
    cookies = Plug.Conn.fetch_cookies(conn, signed: ["client_secret"]).cookies
    client_secret = Map.get(cookies, "client_secret")

    conn
    |> assign(:page_title, "BAR - autohost #{autohost.name}")
    |> Plug.Conn.delete_resp_cookie("client_secret", sign: true)
    |> render("show.html",
      autohost: autohost,
      applications: applications,
      credentials: credentials,
      client_secret: client_secret
    )
  end
end
