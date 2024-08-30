defmodule TeiserverWeb.Admin.DiscordChannelController do
  use TeiserverWeb, :controller

  alias Teiserver.{Communication}
  alias Teiserver.Communication.DiscordChannelLib
  import Teiserver.Helper.StringHelper, only: [convert_textarea_to_array: 1]
  alias Teiserver.Helper.StylingHelper

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Communication.DiscordChannel,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "admin",
    sub_menu_active: "discord_channel"
  )

  plug :add_breadcrumb, name: "Admin", url: "/teiserver/admin"
  plug :add_breadcrumb, name: "Discord channels", url: "/admin/discord_channels"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    discord_channels =
      Communication.list_discord_channels(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Name (A-Z)"
      )

    conn
    |> assign(:discord_channels, discord_channels)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    discord_channel = Communication.get_discord_channel!(id)

    conn
    |> assign(:discord_channel, discord_channel)
    |> add_breadcrumb(name: "Show: #{discord_channel.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset =
      Communication.change_discord_channel(%Communication.DiscordChannel{
        icon: "fa-solid fa-" <> StylingHelper.random_icon(),
        colour: StylingHelper.random_colour()
      })

    conn
    |> assign(:special_names, get_special_names())
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New lobby policy", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"discord_channel" => params}) do
    name =
      if String.starts_with?(params["special_name"], "--") do
        params["name"]
      else
        params["special_name"]
      end

    discord_channel_params = Map.put(params, "name", name)

    case Communication.create_discord_channel(discord_channel_params) do
      {:ok, _discord_channel} ->
        conn
        |> put_flash(:info, "Lobby policy created successfully.")
        |> redirect(to: ~p"/admin/discord_channels/")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> assign(:special_names, get_special_names())
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    discord_channel = Communication.get_discord_channel!(id)

    changeset = Communication.change_discord_channel(discord_channel)

    conn
    |> assign(:discord_channel, discord_channel)
    |> assign(:special_names, get_special_names())
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{discord_channel.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "discord_channel" => discord_channel_params}) do
    discord_channel_params =
      Map.merge(discord_channel_params, %{
        "triggers" =>
          (discord_channel_params["triggers"] || "")
          |> String.downcase()
          |> convert_textarea_to_array
          |> Enum.sort()
      })

    discord_channel = Communication.get_discord_channel!(id)

    case Communication.update_discord_channel(discord_channel, discord_channel_params) do
      {:ok, _discord_channel} ->
        conn
        |> put_flash(:info, "Lobby policy updated successfully.")
        |> redirect(to: ~p"/admin/discord_channels")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:discord_channel, discord_channel)
        |> assign(:special_names, get_special_names())
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    discord_channel = Communication.get_discord_channel!(id)

    {:ok, _discord_channel} = Communication.delete_discord_channel(discord_channel)

    conn
    |> put_flash(:info, "Lobby policy deleted successfully.")
    |> redirect(to: ~p"/admin/discord_channels")
  end

  defp get_special_names() do
    existing_names =
      Communication.list_discord_channels(select: [:name], limit: :infinity)
      |> Enum.map(fn %{name: name} -> name end)

    [
      "-- Channels",
      DiscordChannelLib.special_channels(),
      "-- Counters",
      DiscordChannelLib.counter_channels()
    ]
    |> List.flatten()
    |> Enum.reject(fn name ->
      Enum.member?(existing_names, name)
    end)
  end
end
