defmodule TeiserverWeb.Moderation.ActionController do
  @moduledoc false
  use TeiserverWeb, :controller

  alias Teiserver.Logging
  alias Teiserver.{Account, Moderation, Communication}
  alias Teiserver.Moderation.{Action, ActionLib, ReportLib}
  import Teiserver.Logging.Helpers, only: [add_audit_log: 3]
  import Teiserver.Helper.StringHelper, only: [get_hash_id: 1]

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderation.Action,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "moderation",
    sub_menu_active: "action"
  )

  plug TeiserverWeb.Plugs.PaginationParams

  plug :add_breadcrumb, name: "Moderation", url: "/teiserver"
  plug :add_breadcrumb, name: "Actions", url: "/teiserver/actions"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    page = params["page"] - 1
    limit = params["limit"]

    search_args = extract_search_params(params)

    total_count = Moderation.count_actions(search: search_args)
    total_pages = div(total_count - 1, limit) + 1

    actions =
      Moderation.list_actions(
        search: search_args,
        preload: [:target],
        order_by: params["order"] || "Most recently inserted first",
        limit: limit,
        offset: page * limit
      )

    conn
    |> assign(:actions, actions)
    |> assign(:page, page)
    |> assign(:limit, limit)
    |> assign(:total_pages, total_pages)
    |> assign(:total_count, total_count)
    |> assign(:current_count, Enum.count(actions))
    |> assign(:params, Map.put(params, "limit", limit))
    |> render("index.html")
  end

  defp extract_search_params(params) do
    search_params = []

    search_params =
      if params["target_id"] && params["target_id"] != "" do
        [target_id: params["target_id"]] ++ search_params
      else
        search_params
      end

    search_params =
      if params["reporter_id"] && params["reporter_id"] != "" do
        [reporter_id: params["reporter_id"]] ++ search_params
      else
        search_params
      end

    search_params =
      if params["expiry"] && params["expiry"] != "All" do
        [expiry: params["expiry"]] ++ search_params
      else
        search_params
      end

    search_params
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    action =
      Moderation.get_action!(id,
        preload: [:target]
      )

    logs =
      Logging.list_audit_logs(
        search: [
          actions: [
            "Moderation:Action halted",
            "Moderation:Action updated",
            "Moderation:Action created"
          ],
          details_equal: {"action_id", action.id |> to_string}
        ],
        joins: [:user],
        order_by: "Newest first"
      )

    action
    |> ActionLib.make_favourite()
    |> insert_recently(conn)

    conn
    |> assign(:use_discord, Communication.DiscordChannelLib.use_discord?())
    |> assign(:guild_id, Communication.DiscordChannelLib.get_guild_id())
    |> assign(
      :channel,
      Communication.DiscordChannelLib.get_discord_channel("Public moderation log")
    )
    |> assign(:action, action)
    |> assign(:logs, logs)
    |> add_breadcrumb(
      name: "Show: #{action.target.name} - #{Enum.join(action.restrictions, ", ")}",
      url: conn.request_path
    )
    |> render("show.html")
  end

  @spec new_with_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new_with_user(conn, params) do
    user =
      case params do
        %{"userid" => userid_str} ->
          Account.get_user(userid_str)

        %{"teiserver_user" => userid_str} ->
          cond do
            Integer.parse(userid_str) != :error ->
              {user_id, _} = Integer.parse(userid_str)
              Account.get_user(user_id)

            get_hash_id(userid_str) != nil ->
              user_id = get_hash_id(userid_str)
              Account.get_user(user_id)

            true ->
              nil
          end

        _ ->
          nil
      end

    case user do
      nil ->
        conn
        |> add_breadcrumb(name: "New action", url: conn.request_path)
        |> put_flash(:warning, "Unable to find that user")
        |> render("new_select.html")

      user ->
        changeset =
          Moderation.change_action(%Action{
            score_modifier: 0
          })

        reports =
          Moderation.list_reports(
            search: [
              target_id: user.id,
              no_result: true,
              closed: false,
              inserted_after:
                Timex.shift(Timex.now(), days: -ReportLib.get_outstanding_report_max_days())
            ],
            preload: [:reporter],
            order_by: "Newest first",
            limit: :infinity
          )

        past_actions =
          Moderation.list_actions(
            search: [
              target_id: user.id
            ],
            preload: [:target],
            order_by: "Most recently inserted first"
          )

        conn
        |> assign(:user, user)
        |> assign(:changeset, changeset)
        |> assign(:reports, reports)
        |> assign(:past_actions, past_actions)
        |> assign(:selected_report_ids, [])
        |> assign(:restrictions_lists, Teiserver.Account.UserLib.list_restrictions())
        |> add_breadcrumb(name: "New action for #{user.name}", url: conn.request_path)
        |> render("new_with_user.html")
    end
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Moderation.change_action(%Action{})

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New action", url: conn.request_path)
    |> render("new_select.html")
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"action" => action_params}) do
    user = Account.get_user(action_params["target_id"])

    restrictions =
      action_params["restrictions"]
      |> Map.values()
      |> Enum.reject(fn v -> v == "false" end)

    action_params =
      Map.merge(action_params, %{
        "restrictions" => restrictions
      })

    report_ids =
      (action_params["reports"] || %{})
      |> Map.values()
      |> Enum.reject(fn v -> v == "false" end)
      |> Enum.map(fn s -> String.to_integer(s) end)

    case Moderation.create_action(action_params) do
      {:ok, action} ->
        Teiserver.Moderation.RefreshUserRestrictionsTask.refresh_user(action.target_id)
        ActionLib.maybe_create_discord_post(action)

        if not Enum.empty?(report_ids) do
          unique_match_ids =
            Moderation.list_reports(search: [id_list: report_ids], limit: :infinity)
            |> Enum.map(& &1.match_id)
            |> Enum.uniq()

          Enum.each(unique_match_ids, fn match_id ->
            report_group = Moderation.get_report_group_by_match_id(match_id)
            Moderation.close_report_group_if_no_open_reports(report_group)
          end)

          Moderation.list_reports(search: [id_list: report_ids], limit: :infinity)
          |> Enum.each(fn report ->
            Moderation.update_report(report, %{
              result_id: action.id
            })
          end)
        end

        add_audit_log(conn, "Moderation:Action created", %{action_id: action.id})

        conn
        |> put_flash(:info, "Action created successfully.")
        |> redirect(to: Routes.moderation_action_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        reports =
          Moderation.list_reports(
            search: [
              target_id: user.id,
              no_result: true,
              inserted_after:
                Timex.shift(Timex.now(), days: -ReportLib.get_outstanding_report_max_days())
            ],
            preload: [:reporter],
            order_by: "Newest first",
            limit: :infinity
          )

        past_actions =
          Moderation.list_actions(
            search: [
              target_id: user.id
            ],
            preload: [:target],
            order_by: "Most recently inserted first"
          )

        conn
        |> assign(:user, user)
        |> assign(:changeset, changeset)
        |> assign(:reports, reports)
        |> assign(:selected_report_ids, report_ids)
        |> assign(:restrictions_lists, Teiserver.Account.UserLib.list_restrictions())
        |> assign(:past_actions, past_actions)
        |> add_breadcrumb(name: "New action for #{user.name}", url: conn.request_path)
        |> render("new_with_user.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    action = Moderation.get_action!(id, preload: [:target])

    changeset = Moderation.change_action(action)

    conn
    |> assign(:action, action)
    |> assign(:changeset, changeset)
    |> assign(:restrictions_lists, Teiserver.Account.UserLib.list_restrictions())
    |> add_breadcrumb(name: "Edit: #{action.target.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "action" => action_params}) do
    action = Moderation.get_action!(id)

    restrictions =
      action_params["restrictions"]
      |> Map.values()
      |> Enum.reject(fn v -> v == "false" end)

    action_params =
      Map.merge(action_params, %{
        "restrictions" => restrictions
      })

    case Moderation.update_action(action, action_params) do
      {:ok, _action} ->
        action = Moderation.get_action!(id, preload: [:target])

        Teiserver.Moderation.RefreshUserRestrictionsTask.refresh_user(action.target_id)
        ActionLib.maybe_update_discord_post(action)

        add_audit_log(conn, "Moderation:Action updated", %{action_id: action.id})

        conn
        |> put_flash(:info, "Action updated successfully.")
        |> redirect(to: Routes.moderation_action_path(conn, :show, action.id))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:action, action)
        |> assign(:changeset, changeset)
        |> assign(:restrictions_lists, Teiserver.Account.UserLib.list_restrictions())
        |> render("edit.html")
    end
  end

  @spec re_post(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def re_post(conn, %{"id" => id}) do
    action = Moderation.get_action!(id, preload: [:target])

    # First we try to update the message (if we have an ID)
    update_result =
      if action.discord_message_id do
        ActionLib.maybe_update_discord_post(action)
      else
        {:error, "no message_id"}
      end

    Teiserver.Moderation.RefreshUserRestrictionsTask.refresh_user(action.target_id)

    case update_result do
      {:error, _} ->
        ActionLib.maybe_create_discord_post(action)
        add_audit_log(conn, "Moderation:Action re_posted", %{action_id: action.id})

        conn
        |> put_flash(:info, "Action re-posted.")
        |> redirect(to: Routes.moderation_action_path(conn, :show, action.id))

      {:ok, _} ->
        conn
        |> put_flash(:info, "Action updated.")
        |> redirect(to: Routes.moderation_action_path(conn, :show, action.id))
    end
  end

  @spec halt(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def halt(conn, %{"id" => id}) do
    action = Moderation.get_action!(id)

    case Moderation.update_action(action, %{"expires" => Timex.now()}) do
      {:ok, _action} ->
        add_audit_log(conn, "Moderation:Action halted", %{action_id: action.id})
        ActionLib.maybe_update_discord_post(action)
        Teiserver.Moderation.RefreshUserRestrictionsTask.refresh_user(action.target_id)

        conn
        |> put_flash(:info, "Action halted.")
        |> redirect(to: Routes.moderation_action_path(conn, :show, action.id))
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    action = Moderation.get_action!(id)

    # Update any reports which were assigned to this
    # action.report_groups
    # |> Enum.each(fn report ->
    #   Moderation.update_report(report, %{result_id: nil})
    # end)

    Moderation.delete_action(action)

    if action.discord_message_id do
      Communication.delete_discord_message("Public moderation log", action.discord_message_id)
    end

    action_map =
      Map.take(action, ~w(target_id reason restrictions score_modifier expires hidden)a)

    add_audit_log(conn, "Moderation:Action deleted", %{action: action_map})
    Teiserver.Moderation.RefreshUserRestrictionsTask.refresh_user(action.target_id)

    conn
    |> put_flash(:info, "Action deleted.")
    |> redirect(to: Routes.moderation_action_path(conn, :index))
  end
end
