defmodule TeiserverWeb.Moderation.ActionController do
  @moduledoc false
  use CentralWeb, :controller

  alias Teiserver.Logging
  alias Teiserver.{Account, Moderation}
  alias Teiserver.Moderation.{Action, ActionLib, ReportLib}
  import Teiserver.Logging.Helpers, only: [add_audit_log: 3]
  import Central.Helpers.StringHelper, only: [get_hash_id: 1]

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderation.Action,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "moderation",
    sub_menu_active: "action"
  )

  plug :add_breadcrumb, name: 'Moderation', url: '/teiserver'
  plug :add_breadcrumb, name: 'Actions', url: '/teiserver/actions'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    actions =
      Moderation.list_actions(
        search: [
          target_id: params["target_id"],
          reporter_id: params["reporter_id"]
        ],
        preload: [:target],
        order_by: "Most recently inserted first"
      )

    conn
    |> assign(:params, %{})
    |> assign(:actions, actions)
    |> render("index.html")
  end

  @spec search(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def search(conn, %{"search" => params}) do
    actions =
      Moderation.list_actions(
        search: [
          target_id: params["target_id"],
          reporter_id: params["reporter_id"],
          expiry: params["expiry"]
        ],
        preload: [:target],
        order_by: params["order"]
      )

    conn
    |> assign(:params, params)
    |> assign(:actions, actions)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    action =
      Moderation.get_action!(id,
        preload: [:target, :reports_and_reporters]
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
    |> assign(:action, action)
    |> assign(:logs, logs)
    |> add_breadcrumb(
      name: "Show: #{action.target.name} - #{Enum.join(action.restrictions, ", ")}",
      url: conn.request_path
    )
    |> render("show.html")
  end

  @spec new_with_user(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
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
              inserted_after:
                Timex.shift(Timex.now(), days: -ReportLib.get_outstanding_report_max_days())
            ],
            preload: [:reporter],
            order_by: "Newest first",
            limit: :infinity
          )

        conn
        |> assign(:user, user)
        |> assign(:changeset, changeset)
        |> assign(:reports, reports)
        |> assign(:selected_report_ids, [])
        |> assign(:restrictions_lists, Central.Account.UserLib.list_restrictions())
        |> add_breadcrumb(name: "New action for #{user.name}", url: conn.request_path)
        |> render("new_with_user.html")
    end
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Moderation.change_action(%Action{})

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New action", url: conn.request_path)
    |> render("new_select.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
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

        if not Enum.empty?(report_ids) do
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

        conn
        |> assign(:user, user)
        |> assign(:changeset, changeset)
        |> assign(:reports, reports)
        |> assign(:selected_report_ids, report_ids)
        |> assign(:restrictions_lists, Central.Account.UserLib.list_restrictions())
        |> add_breadcrumb(name: "New action for #{user.name}", url: conn.request_path)
        |> render("new_with_user.html")
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    action = Moderation.get_action!(id, preload: [:target])

    changeset = Moderation.change_action(action)

    conn
    |> assign(:action, action)
    |> assign(:changeset, changeset)
    |> assign(:restrictions_lists, Central.Account.UserLib.list_restrictions())
    |> add_breadcrumb(name: "Edit: #{action.target.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
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
        Teiserver.Moderation.RefreshUserRestrictionsTask.refresh_user(action.target_id)

        add_audit_log(conn, "Moderation:Action updated", %{action_id: action.id})

        conn
        |> put_flash(:info, "Action updated successfully.")
        |> redirect(to: Routes.moderation_action_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:action, action)
        |> assign(:changeset, changeset)
        |> assign(:restrictions_lists, Central.Account.UserLib.list_restrictions())
        |> render("edit.html")
    end
  end

  @spec halt(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def halt(conn, %{"id" => id}) do
    action = Moderation.get_action!(id)

    case Moderation.update_action(action, %{"expires" => Timex.now()}) do
      {:ok, _action} ->
        add_audit_log(conn, "Moderation:Action halted", %{action_id: action.id})
        Teiserver.Moderation.RefreshUserRestrictionsTask.refresh_user(action.target_id)

        conn
        |> put_flash(:info, "Action halted.")
        |> redirect(to: Routes.moderation_action_path(conn, :index))
    end
  end
end
