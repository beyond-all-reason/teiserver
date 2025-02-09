defmodule TeiserverWeb.Admin.BotController do
  @moduledoc """
  management of bots and their credentials
  """

  use TeiserverWeb, :controller

  alias Teiserver.{Bot, BotQueries, OAuth}
  alias Teiserver.OAuth.{ApplicationQueries, CredentialQueries}

  plug Bodyguard.Plug.Authorize,
    # The policy should be Admin or something fairly high. But while we're
    # developping the new lobby, it's easier if this is allowed for any
    # contributors
    policy: Teiserver.Staff,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: "Admin", url: "/teiserver/admin"
  plug :add_breadcrumb, name: "Bots", url: "/teiserver/admin/bot"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    bots = BotQueries.list_bots()
    cred_counts = CredentialQueries.count_per_bots(Enum.map(bots, fn a -> a.id end))

    conn
    |> render("index.html", bots: bots, cred_counts: cred_counts)
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Bot.change_bot(%Bot.Bot{})

    conn
    |> assign(:page_title, "")
    |> render("new.html", changeset: changeset)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"bot" => attrs}) do
    case Bot.create_bot(attrs) do
      {:ok, %Bot.Bot{} = bot} ->
        conn
        |> put_flash(:info, "Bot created")
        |> redirect(to: ~p"/teiserver/admin/bot/#{bot.id}")

      {:error, changeset} ->
        conn
        |> assign(:page_title, "BAR - new bot")
        |> put_status(400)
        |> render("new.html", changeset: changeset)
    end
  end

  def create(conn, _),
    do:
      conn
      |> put_status(400)
      |> assign(:page_title, "BAR - new bot")
      |> render("new.html", changeset: Bot.Bot.changeset(%Bot.Bot{}, %{}))

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, assigns) do
    case Bot.get_by_id(Map.get(assigns, "id")) do
      %Bot.Bot{} = bot ->
        render_show(conn, bot)

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, assigns) do
    case Bot.get_by_id(Map.get(assigns, "id")) do
      %Bot.Bot{} = bot ->
        changeset = Bot.change_bot(bot)

        conn
        |> assign(:page_title, "BAR - edit bot #{bot.name}")
        |> render("edit.html", bot: bot, changeset: changeset)

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"bot" => params} = assigns) do
    case Bot.get_by_id(Map.get(assigns, "id")) do
      %Bot.Bot{} = bot ->
        case Bot.update_bot(bot, params) do
          {:ok, bot} ->
            conn
            |> put_flash(:info, "Bot updated")
            |> render_show(bot)

          {:error, changeset} ->
            conn
            |> put_status(400)
            |> render(:edit, bot: bot, changeset: changeset)
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
    case Bot.get_by_id(Map.get(assigns, "id")) do
      %Bot.Bot{} = bot ->
        case Bot.delete(bot) do
          :ok ->
            conn
            |> put_flash(:info, "Deleted!")
            |> redirect(to: ~p"/teiserver/admin/bot")

          {:error, err} ->
            conn
            |> put_flash(:danger, inspect(err))
            |> redirect(to: ~p"/teiserver/admin/bot/#{bot.id}")
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec create_credential(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_credential(conn, assigns) do
    with bot when not is_nil(bot) <- Bot.get_by_id(Map.get(assigns, "id")),
         app when not is_nil(app) <-
           ApplicationQueries.get_application_by_id(Map.get(assigns, "application")) do
      client_id = UUID.uuid4()
      secret = Base.hex_encode32(:crypto.strong_rand_bytes(32))

      case OAuth.create_credentials(app, bot, client_id, secret) do
        {:ok, _cred} ->
          conn
          |> put_flash(:info, "credential created")
          |> Plug.Conn.put_resp_cookie("client_secret", secret, sign: true, max_age: 60)
          |> redirect(to: ~p"/teiserver/admin/bot/#{bot.id}")

        {:error, err} ->
          conn
          |> put_flash(:danger, inspect(err))
          |> render_show(bot)
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
    with bot when not is_nil(bot) <- Bot.get_by_id(Map.get(assigns, "id")),
         cred when not is_nil(cred) <-
           CredentialQueries.get_credential_by_id(Map.get(assigns, "cred_id")) do
      if cred.bot_id != bot.id do
        conn
        |> put_status(:bad_request)
        |> put_flash(:danger, "credential doesn't match bot")
        |> render_show(bot)
      else
        case OAuth.delete_credential(cred) do
          :ok ->
            conn
            |> put_flash(:info, "credential deleted")
            |> redirect(to: ~p"/teiserver/admin/bot/#{bot.id}")

          {:error, err} ->
            conn
            |> put_flash(:danger, inspect(err))
            |> render_show(bot)
        end
      end
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  defp render_show(conn, bot) do
    applications = ApplicationQueries.list_applications()
    credentials = CredentialQueries.for_bot(bot)
    cookies = Plug.Conn.fetch_cookies(conn, signed: ["client_secret"]).cookies
    client_secret = Map.get(cookies, "client_secret")

    conn
    |> assign(:page_title, "BAR - bot #{bot.name}")
    |> Plug.Conn.delete_resp_cookie("client_secret", sign: true)
    |> render("show.html",
      bot: bot,
      applications: applications,
      credentials: credentials,
      client_secret: client_secret
    )
  end
end
