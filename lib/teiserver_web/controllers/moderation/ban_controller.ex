defmodule TeiserverWeb.Moderation.BanController do
  @moduledoc false
  use TeiserverWeb, :controller

  alias Teiserver.Logging
  alias Teiserver.{Account, Moderation}
  alias Teiserver.Moderation.{Ban, BanLib, ActionLib}
  import Teiserver.Helper.StringHelper, only: [get_hash_id: 1]

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderation.Ban,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "moderation",
    sub_menu_active: "ban"
  )

  plug :add_breadcrumb, name: "Moderation", url: "/teiserver"
  plug :add_breadcrumb, name: "Bans", url: "/teiserver/bans"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    page = (params["page"] || "1") |> String.to_integer() |> max(1) |> then(&(&1 - 1))
    limit = (params["limit"] || "50") |> String.to_integer() |> max(1)

    search_args = extract_search_params(params)

    total_count = Moderation.count_bans(search: search_args)
    total_pages = div(total_count - 1, limit) + 1

    bans =
      Moderation.list_bans(
        search: search_args,
        preload: [:adder, :source],
        order_by: params["order"] || "Newest first",
        limit: limit,
        offset: page * limit
      )

    conn
    |> assign(:bans, bans)
    |> assign(:page, page)
    |> assign(:limit, limit)
    |> assign(:total_pages, total_pages)
    |> assign(:total_count, total_count)
    |> assign(:current_count, Enum.count(bans))
    |> assign(:params, Map.put(params, "limit", limit))
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    ban =
      Moderation.get_ban!(id,
        preload: [:adder, :source]
      )

    logs =
      Logging.list_audit_logs(
        search: [
          actions: [
            "Moderation:Ban updated",
            "Moderation:Ban enacted"
          ],
          details_equal: {"ban_id", ban.id |> to_string}
        ],
        joins: [:user],
        order_by: "Newest first"
      )

    ban
    |> BanLib.make_favourite()
    |> insert_recently(conn)

    targets =
      logs
      |> Enum.map(fn log -> log.details["target_user_id"] end)
      |> Enum.reject(&(&1 == nil))
      |> Map.new(fn userid ->
        {userid, Account.get_username(userid)}
      end)

    conn
    |> assign(:ban, ban)
    |> assign(:logs, logs)
    |> assign(:targets, targets)
    |> assign(:user_stats, Teiserver.Account.get_user_stat_data(ban.source_id))
    |> add_breadcrumb(name: "Show: #{ban.source.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new_with_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new_with_user(conn, %{"teiserver_user" => user_str}) do
    user =
      cond do
        Integer.parse(user_str) != :error ->
          {user_id, _} = Integer.parse(user_str)
          Account.get_user(user_id)

        get_hash_id(user_str) != nil ->
          user_id = get_hash_id(user_str)
          Account.get_user(user_id)

        true ->
          nil
      end

    existing_ban = Moderation.get_ban(nil, search: [source_id: user.id])

    cond do
      user == nil ->
        conn
        |> add_breadcrumb(name: "New ban", url: conn.request_path)
        |> put_flash(:warning, "Unable to find that user")
        |> render("new_select.html")

      existing_ban != nil ->
        conn
        |> redirect(to: Routes.moderation_ban_path(conn, :show, existing_ban.id))

      true ->
        matching_users =
          Account.smurf_search(user)
          |> Enum.map(fn {_type, users} -> users end)
          |> List.flatten()
          |> Enum.map(fn %{user: user} -> user.id end)
          |> Enum.uniq()
          |> Enum.map(fn userid -> Account.get_user_by_id(userid) end)
          |> Enum.reject(fn user ->
            Teiserver.CacheUser.is_restricted?(user, ["Login", "All lobbies", "All chat"])
          end)

        all_user_keys =
          Account.list_smurf_keys(
            search: [
              user_id: user.id
            ],
            limit: :infinity,
            preload: [:type],
            order_by: "Newest first"
          )

        key_types = Account.list_smurf_key_types(limit: :infinity)

        # Update their hw_key
        hw_fingerprint =
          user.id
          |> Account.get_user_stat_data()
          |> Teiserver.Account.CalculateSmurfKeyTask.calculate_hw1_fingerprint()

        Account.update_user_stat(user.id, %{
          hw_fingerprint: hw_fingerprint
        })

        user_stats =
          case Account.get_user_stat(user.id) do
            nil -> %{}
            stats -> stats.data
          end

        changeset = Moderation.change_ban(%Ban{source_id: user.id})

        conn
        |> assign(:extra_values, [])
        |> assign(:key_types, key_types)
        |> assign(:matching_users, matching_users)
        |> assign(:changeset, changeset)
        |> assign(:user, user)
        |> assign(:user_stats, user_stats)
        |> assign(:all_user_keys, all_user_keys)
        |> add_breadcrumb(name: "New ban for #{user.name}", url: conn.request_path)
        |> render("new_with_user.html")
    end
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    conn
    |> add_breadcrumb(name: "New ban", url: conn.request_path)
    |> render("new_select.html")
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"ban" => ban_params}) do
    key_values =
      ban_params["key_values"]
      |> Enum.reject(fn r -> r == "false" end)

    ban_params =
      Map.merge(ban_params, %{
        "added_by_id" => conn.assigns.current_user.id,
        "key_values" => key_values
      })

    case Moderation.create_ban(ban_params) do
      {:ok, ban} ->
        # Now ban the user themselves
        {:ok, action} =
          Moderation.create_action(%{
            target_id: ban.source_id,
            reason: ban.reason,
            restrictions: ["Login"],
            score_modifier: 0,
            expires: Timex.now() |> Timex.shift(years: 1000)
          })

        ActionLib.maybe_create_discord_post(action)

        Teiserver.Moderation.RefreshUserRestrictionsTask.refresh_user(ban.source_id)

        conn
        |> put_flash(:info, "Ban created successfully.")
        |> redirect(to: Routes.moderation_ban_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        user = Account.get_user(ban_params["source_id"])

        matching_users =
          Account.smurf_search(user)
          |> Enum.map(fn {_type, users} -> users end)
          |> List.flatten()
          |> Enum.map(fn %{user: user} -> user.id end)
          |> Enum.uniq()
          |> Enum.map(fn userid -> Account.get_user_by_id(userid) end)
          |> Enum.reject(fn user ->
            Teiserver.CacheUser.is_restricted?(user, ["Login"])
          end)

        all_user_keys =
          Account.list_smurf_keys(
            search: [
              user_id: user.id
            ],
            limit: :infinity,
            preload: [:type],
            order_by: "Newest first"
          )

        key_types = Account.list_smurf_key_types(limit: :infinity)

        # Update their hw_key
        hw_fingerprint =
          user.id
          |> Account.get_user_stat_data()
          |> Teiserver.Account.CalculateSmurfKeyTask.calculate_hw1_fingerprint()

        Account.update_user_stat(user.id, %{
          hw_fingerprint: hw_fingerprint
        })

        user_stats =
          case Account.get_user_stat(user.id) do
            nil -> %{}
            stats -> stats.data
          end

        conn
        |> assign(:key_types, key_types)
        |> assign(:matching_users, matching_users)
        |> assign(:changeset, changeset)
        |> assign(:user, user)
        |> assign(:user_stats, user_stats)
        |> assign(:all_user_keys, all_user_keys)
        |> add_breadcrumb(name: "New ban", url: conn.request_path)
        |> render("new_with_user.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    ban = Moderation.get_ban!(id, preload: [:source])

    changeset = Moderation.change_ban(ban)

    all_user_keys =
      Account.list_smurf_keys(
        search: [
          user_id: ban.source_id
        ],
        limit: :infinity,
        preload: [:type],
        order_by: "Newest first"
      )

    user_key_values =
      all_user_keys
      |> Enum.map(fn k -> k.value end)

    extra_values =
      ban.key_values
      |> Enum.reject(fn v ->
        Enum.member?(user_key_values, v)
      end)

    conn
    |> assign(:extra_values, extra_values)
    |> assign(:ban, ban)
    |> assign(:all_user_keys, all_user_keys)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{ban.source.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "ban" => ban_params}) do
    ban = Moderation.get_ban!(id)

    key_values =
      ban_params["key_values"]
      |> Enum.reject(fn r -> r == "false" end)

    extra_values =
      ban_params["extra_values"]
      |> String.split("\n")
      |> Enum.reject(fn v ->
        v == "" or v == nil
      end)

    ban_params =
      Map.merge(ban_params, %{
        "key_values" => Enum.uniq(key_values ++ extra_values)
      })

    case Moderation.update_ban(ban, ban_params) do
      {:ok, _ban} ->
        conn
        |> put_flash(:info, "Ban updated successfully.")
        |> redirect(to: ~p"/moderation/ban/#{ban.id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:ban, ban)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec enable(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def enable(conn, %{"id" => id}) do
    ban = Moderation.get_ban!(id)

    case Moderation.update_ban(ban, %{"enabled" => true}) do
      {:ok, _ban} ->
        add_audit_log(conn, "Moderation:Ban enabled", %{ban_id: ban.id})

        conn
        |> put_flash(:info, "Ban enabled.")
        |> redirect(to: Routes.moderation_ban_path(conn, :index))
    end
  end

  @spec disable(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def disable(conn, %{"id" => id}) do
    ban = Moderation.get_ban!(id)

    case Moderation.update_ban(ban, %{"enabled" => false}) do
      {:ok, _ban} ->
        add_audit_log(conn, "Moderation:Ban disabled", %{ban_id: ban.id})

        conn
        |> put_flash(:info, "Ban disabled.")
        |> redirect(to: Routes.moderation_ban_path(conn, :index))
    end
  end

  defp extract_search_params(params) do
    search_params = []

    search_params =
      if params["name"] && params["name"] != "" do
        [name: params["name"]] ++ search_params
      else
        search_params
      end

    search_params
  end
end
