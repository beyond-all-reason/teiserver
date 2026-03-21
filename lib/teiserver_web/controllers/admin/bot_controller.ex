defmodule TeiserverWeb.Admin.BotController do
  @moduledoc """
  management of bots and their credentials
  """

  alias Plug.Conn
  alias Teiserver.Account.AuthLib
  alias Teiserver.Bot
  alias Teiserver.Bot.Bot, as: BotSchema
  alias Teiserver.BotQueries
  alias Teiserver.OAuth
  alias Teiserver.OAuth.ApplicationQueries
  alias Teiserver.OAuth.CredentialQueries

  use TeiserverWeb, :controller

  plug Bodyguard.Plug.Authorize,
    # The policy should be Admin or something fairly high. But while we're
    # developping the new lobby, it's easier if this is allowed for any
    # contributors
    policy: Teiserver.Staff,
    action: {Phoenix.Controller, :action_name},
    user: {AuthLib, :current_user}

  plug :add_breadcrumb, name: "Admin", url: "/teiserver/admin"
  plug :add_breadcrumb, name: "Bots", url: "/teiserver/admin/bot"

  @spec index(Conn.t(), map()) :: Conn.t()
  def index(conn, _params) do
    bots = BotQueries.list_bots()
    cred_counts = bots |> Enum.map(fn a -> a.id end) |> CredentialQueries.count_per_bots()

    conn
    |> render("index.html", bots: bots, cred_counts: cred_counts)
  end

  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, _params) do
    changeset = Bot.change_bot(%BotSchema{})

    conn
    |> assign(:page_title, "")
    |> render("new.html", changeset: changeset)
  end

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"bot" => attrs}) do
    case Bot.create_bot(attrs) do
      {:ok, %BotSchema{} = bot} ->
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

  def create(conn, _params),
    do:
      conn
      |> put_status(400)
      |> assign(:page_title, "BAR - new bot")
      |> render("new.html", changeset: BotSchema.changeset(%BotSchema{}, %{}))

  @spec show(Conn.t(), map()) :: Conn.t()
  def show(conn, assigns) do
    case assigns |> Map.get("id") |> Bot.get_by_id() do
      %BotSchema{} = bot ->
        render_show(conn, bot)

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec edit(Conn.t(), map()) :: Conn.t()
  def edit(conn, assigns) do
    case assigns |> Map.get("id") |> Bot.get_by_id() do
      %BotSchema{} = bot ->
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

  @spec update(Conn.t(), map()) :: Conn.t()
  def update(conn, %{"bot" => params} = assigns) do
    case assigns |> Map.get("id") |> Bot.get_by_id() do
      %BotSchema{} = bot ->
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

  def update(conn, _params) do
    conn
    |> put_status(:not_found)
    |> render("not_found.html")
  end

  @spec delete(Conn.t(), map()) :: Conn.t()
  def delete(conn, assigns) do
    case assigns |> Map.get("id") |> Bot.get_by_id() do
      %BotSchema{} = bot ->
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

  @spec create_credential(Conn.t(), map()) :: Conn.t()
  def create_credential(conn, assigns) do
    with bot when not is_nil(bot) <- assigns |> Map.get("id") |> Bot.get_by_id(),
         app when not is_nil(app) <-
           assigns |> Map.get("application") |> ApplicationQueries.get_application_by_id() do
      client_id = UUID.uuid4()
      secret = 32 |> :crypto.strong_rand_bytes() |> Base.hex_encode32()

      case OAuth.create_credentials(app, bot, client_id, secret) do
        {:ok, _cred} ->
          conn
          |> put_flash(:info, "credential created")
          |> Conn.put_resp_cookie("client_secret", secret, sign: true, max_age: 60)
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

  @spec delete_credential(Conn.t(), map()) :: Conn.t()
  def delete_credential(conn, assigns) do
    with bot when not is_nil(bot) <- assigns |> Map.get("id") |> Bot.get_by_id(),
         cred when not is_nil(cred) <-
           assigns |> Map.get("cred_id") |> CredentialQueries.get_credential_by_id() do
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
    cookies = Conn.fetch_cookies(conn, signed: ["client_secret"]).cookies
    client_secret = Map.get(cookies, "client_secret")

    conn
    |> assign(:page_title, "BAR - bot #{bot.name}")
    |> Conn.delete_resp_cookie("client_secret", sign: true)
    |> render("show.html",
      bot: bot,
      applications: applications,
      credentials: credentials,
      client_secret: client_secret
    )
  end
end
