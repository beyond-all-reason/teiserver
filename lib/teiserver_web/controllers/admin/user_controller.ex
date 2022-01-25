defmodule TeiserverWeb.Admin.UserController do
  use CentralWeb, :controller

  alias Teiserver.{Account, Chat}
  alias Central.Account.User
  alias Teiserver.Account.UserLib
  alias Central.Account.GroupLib

  plug(AssignPlug,
    site_menu_active: "teiserver_user",
    sub_menu_active: "user",
  )

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.Auth,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}
  )

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin')
  plug(:add_breadcrumb, name: 'Users', url: '/teiserver/admin/user')

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    users =
      Account.list_users(
        search: [
          admin_group: conn,
          simple_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Newest first",
        limit: 50
      )

    if Enum.count(users) == 1 do
      conn
      |> redirect(to: Routes.ts_admin_user_path(conn, :show, hd(users).id))
    else
      conn
      |> add_breadcrumb(name: "List users", url: conn.request_path)
      |> assign(:users, users)
      |> assign(:params, search_defaults(conn))
      |> render("index.html")
    end
  end

  @spec search(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def search(conn, %{"search" => params}) do
    params = Map.merge(search_defaults(conn), params)

    id_list = Account.list_user_stats(
      search: [
        data_contains: {"previous_names", params["previous_names"]}
      ],
      select: [:user_id]
    )
    |> Enum.map(fn s -> s.user_id end)

    users =
      Account.list_users(
        search: [
          admin_group: conn,
          simple_search: Map.get(params, "name", "") |> String.trim(),
          bot: params["bot"],
          moderator: params["moderator"],
          verified: params["verified"],
          trusted: params["trusted"],
          tester: params["tester"],
          streamer: params["streamer"],
          donor: params["donor"],
          contributor: params["contributor"],
          developer: params["developer"],
          ip: params["ip"],
          lobby_client: params["lobby_client"],
          previous_names: params["previous_names"],
          mod_action: params["mod_action"]
        ],
        limit: params["limit"] || 50,
        order_by: params["order"] || "Name (A-Z)"
      )
      ++ Account.list_users(search: [id_in: id_list])
      |> Enum.uniq

    # if Enum.count(users) == 1 do
    #   conn
    #   |> redirect(to: Routes.ts_admin_user_path(conn, :show, hd(users).id))
    # else
      conn
      |> add_breadcrumb(name: "User search", url: conn.request_path)
      |> assign(:params, params)
      |> assign(:users, users)
      |> render("index.html")
    # end
  end

  @spec data_search(Plug.Conn.t(), map) :: Plug.Conn.t()
  def data_search(conn, params) do
    users = if params["data_search"] == nil do
      []
    else
      id_list = Teiserver.Account.list_user_stats(limit: :infinity)
      |> Teiserver.Account.UserStatLib.field_contains("hardware:gpuinfo", params["data_search"]["gpu"])
      |> Teiserver.Account.UserStatLib.field_contains("hardware:cpuinfo", params["data_search"]["cpu"])
      |> Teiserver.Account.UserStatLib.field_contains("hardware:osinfo", params["data_search"]["os"])
      |> Teiserver.Account.UserStatLib.field_contains("hardware:raminfo", params["data_search"]["ram"])
      |> Stream.map(fn stats -> stats.user_id end)
      |> Stream.take(50)
      |> Enum.to_list

      Account.list_users(search: [id_in: id_list])
    end

    conn
    |> add_breadcrumb(name: "Data search", url: conn.request_path)
    |> assign(:params, params["data_search"])
    |> assign(:data_search, true)
    |> assign(:users, users)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    user = Account.get_user(id)

    case Central.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        reports =
          Central.Account.list_reports(
            search: [
              filter: {"target", user.id}
            ],
            preload: [
              :reporter,
              :target,
              :responder
            ],
            order_by: "Newest first"
          )

        user
        |> UserLib.make_favourite()
        |> insert_recently(conn)

        user_stats = Account.get_user_stat_data(user.id)

        conn
        |> assign(:coc_lookup, Teiserver.Account.CodeOfConductData.flat_data())
        |> assign(:user, user)
        |> assign(:user_stats, user_stats)
        |> assign(:roles, Account.get_roles(user))
        |> assign(:reports, reports)
        |> assign(:section_menu_active, "show")
        |> add_breadcrumb(name: "Show: #{user.name}", url: conn.request_path)
        |> render("show.html")

      _ ->
        conn
        |> put_flash(:warning, "Unable to access this user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end

  @spec new(Plug.Conn.t(), map) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset =
      Account.change_user(%User{
        icon: "fas fa-user",
        colour: "#AA0000"
      })

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New user", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    user_params =
      Map.merge(user_params, %{
        "admin_group_id" => Teiserver.user_group_id(),
        "password" => "pass",
        "data" => %{
          "rank" => 1,
          "friends" => [],
          "friend_requests" => [],
          "ignored" => [],
          "bot" => user_params["bot"] == "true",
          "moderator" => user_params["moderator"] == "true",
          "verified" => user_params["verified"] == "true",
          "password_hash" => "X03MO1qnZdYdgyfeuILPmQ=="
        }
      })

    case Account.create_user(user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  @spec edit(Plug.Conn.t(), map) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    user = Account.get_user(id)

    case Central.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        changeset = Account.change_user(user)

        conn
        |> assign(:user, user)
        |> assign(:changeset, changeset)
        |> assign(:groups, GroupLib.dropdown(conn))
        |> add_breadcrumb(name: "Edit: #{user.name}", url: conn.request_path)
        |> render("edit.html")

      _ ->
        conn
        |> put_flash(:warning, "Unable to access this user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Account.get_user!(id)

    roles = [
      (if user_params["moderator"] == "true", do: "Moderator"),
      (if user_params["admin"] == "true", do: "Admin"),
      (if user_params["streamer"] == "true", do: "Streamer"),
      (if user_params["trusted"] == "true", do: "Trusted"),
      (if user_params["tester"] == "true", do: "Tester"),
      (if user_params["non-bridged"] == "true", do: "Non-bridged"),
      (if user_params["donor"] == "true", do: "Donor"),
      (if user_params["contributor"] == "true", do: "Contributor"),
      (if user_params["developer"] == "true", do: "Developer"),
    ]
    |> Enum.filter(&(&1 != nil))

    data =
      Map.merge(user.data || %{}, %{
        "bot" => user_params["bot"] == "true",
        "moderator" => user_params["moderator"] == "true",
        "verified" => user_params["verified"] == "true",
        "roles" => roles
      })

    user_params = Map.put(user_params, "data", data)

    case Central.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        case Account.update_user(user, user_params) do
          {:ok, user} ->
            Account.update_user_roles(user)

            conn
            |> put_flash(:info, "User updated successfully.")
            # |> redirect(to: Routes.ts_admin_user_path(conn, :index))
            |> redirect(to: Routes.ts_admin_user_path(conn, :show, user.id))

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, "edit.html", user: user, changeset: changeset)
        end

      _ ->
        conn
        |> put_flash(:warning, "Unable to access this user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end

  @spec reset_password(Plug.Conn.t(), map) :: Plug.Conn.t()
  def reset_password(conn, %{"id" => id}) do
    user = Account.get_user!(id)

    case Central.Account.UserLib.has_access(user, conn) do
      {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))

      {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))

      {true, _} ->
        Central.Account.Emails.password_reset(user)
        |> Central.Mailer.deliver_now()

        conn
        |> put_flash(:success, "Password reset email sent to user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end

  @spec perform_action(Plug.Conn.t(), map) :: Plug.Conn.t()
  def perform_action(conn, %{"id" => id, "action" => action} = params) do
    user = Account.get_user!(id)

    case Central.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        result =
          case action do
            "recache" ->
              Teiserver.User.recache_user(user.id)
              {:ok, nil, ""}

            "reset_flood_protection" ->
              ConCache.put(:teiserver_login_count, user.id, 0)
              {:ok, nil, ""}

            "report_action" ->
              action = params["report_response_action"]
              reason = params["reason"]
              followup = params["followup"]
              code_references = params["code_references"]

              case Central.Account.ReportLib.perform_action(%{}, action, params["until"]) do
                {:ok, expires} ->
                  {:ok, _report} =
                    Central.Account.create_report(%{
                      "location" => "web-admin-instant",
                      "location_id" => nil,
                      "reason" => reason,
                      "reporter_id" => conn.user_id,
                      "target_id" => user.id,
                      "response_text" => reason,
                      "response_action" => params["report_response_action"],
                      "responded_at" => Timex.now(),
                      "followup" => followup,
                      "code_references" => code_references,
                      "expires" => expires,
                      "responder_id" => conn.user_id
                    })

                    {:ok, nil, "#reports_tab"}

                err ->
                  err
              end
          end

        case result do
          {:ok, nil, tab} ->
            conn
            |> put_flash(:info, "Action performed.")
            |> redirect(to: Routes.ts_admin_user_path(conn, :show, user) <> tab)

          {:error, msg} ->
            conn
            |> put_flash(:warning, "There was an error: #{msg}")
            |> redirect(to: Routes.ts_admin_user_path(conn, :show, user))
        end

      _ ->
        conn
        |> put_flash(:warning, "Unable to access this user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end

  @spec respond_form(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def respond_form(conn, %{"id" => id}) do
    report =
      Central.Account.get_report!(id,
        preload: [
          :reporter,
          :target,
          :responder
        ]
      )

    case Central.Account.UserLib.has_access(report.target, conn) do
      {true, _} ->
        changeset = Central.Account.change_report(report)

        fav =
          report
          |> Central.Account.ReportLib.make_favourite()

        conn
        |> assign(:report, report)
        |> assign(:changeset, changeset)
        |> add_breadcrumb(name: "Respond to report against: #{fav.item_label}", url: conn.request_path)
        |> assign(:coc_lookup, Teiserver.Account.CodeOfConductData.flat_data())
        |> render("respond.html")

      _ ->
        conn
        |> put_flash(:warning, "Unable to access this user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end

  @spec respond_post(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def respond_post(conn, %{"id" => id, "report" => report_params}) do
    report = Central.Account.get_report!(id, preload: [:target])

    case Central.Account.UserLib.has_access(report.target, conn) do
      {true, _} ->
        case Central.Account.ReportLib.perform_action(
               report,
               report_params["response_action"],
               report_params["response_data"]
             ) do
          {:ok, expires} ->
            report_params =
              Map.merge(report_params, %{
                "expires" => expires,
                "responder_id" => conn.user_id,
                "followup" => report_params["followup"],
                "code_references" => report_params["code_references"],
                "responded_at" => Timex.now(),
              })

            case Central.Account.update_report(report, report_params) do
              {:ok, _report} ->
                conn
                |> put_flash(:success, "Report updated.")
                |> redirect(to: Routes.ts_admin_user_path(conn, :show, report.target_id))

              {:error, %Ecto.Changeset{} = changeset} ->
                conn
                |> assign(:report, report)
                |> assign(:changeset, changeset)
                |> render("respond.html")
            end

          {:error, error} ->
            changeset = Central.Account.change_report(report)

            conn
            |> assign(:error, error)
            |> assign(:report, report)
            |> assign(:changeset, changeset)
            |> assign(:coc_lookup, Teiserver.Account.CodeOfConductData.flat_data())
            |> render("respond.html")
        end

      _ ->
        conn
        |> put_flash(:warning, "Unable to access this user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end

  @spec smurf_search(Plug.Conn.t(), map) :: Plug.Conn.t()
  def smurf_search(conn, %{"id" => id}) do
    user = Account.get_user!(id)

    # Update their hw_key
    hw_fingerprint = Account.get_user_stat(user.id)
    |> Map.get(:data)
    |> Teiserver.Account.RecalculateUserHWTask.calculate_hw_fingerprint()

    Account.update_user_stat(user.id, %{
      hw_fingerprint: hw_fingerprint
    })

    case Central.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        {users, reasons} = Account.smurf_search(conn, user)

        conn
        |> add_breadcrumb(name: "List possible smurfs", url: conn.request_path)
        |> assign(:users, users)
        |> assign(:reasons, reasons)
        |> assign(:params, search_defaults(conn))
        |> render("smurf_list.html")

      _ ->
        conn
        |> put_flash(:warning, "Unable to access this user")
        |> redirect(to: Routes.ts_admin_user_path(conn, :index))
    end
  end

  def banhash_form(conn, %{"id" => id}) do
    user = Account.get_user!(id)

    # Update their hw_key
    hw_fingerprint = Account.get_user_stat_data(user.id)
    |> Teiserver.Account.RecalculateUserHWTask.calculate_hw_fingerprint()

    Account.update_user_stat(user.id, %{
      hw_fingerprint: hw_fingerprint
    })

    user_stats = case Account.get_user_stat(user.id) do
      nil -> %{}
      stats -> stats.data
    end

    conn
    |> add_breadcrumb(name: "Add banhash form", url: conn.request_path)
    |> assign(:user, user)
    |> assign(:user_stats, user_stats)
    |> assign(:userid, user.id)
    |> render("banhash_form.html")
  end

  def full_chat(conn, params = %{"id" => id}) do
    user = Account.get_user!(id)

    mode = case params["mode"] do
      "room" -> "room"
      _ -> "lobby"
    end

    messages = case mode do
      "lobby" ->
        Chat.list_lobby_messages(
          search: [
            user_id: user.id
          ],
          limit: 250,
          order_by: "Newest first"
        )
      "room" ->
        Chat.list_room_messages(
          search: [
            user_id: user.id
          ],
          limit: 250,
          order_by: "Newest first"
        )
    end

    conn
    |> assign(:user, user)
    |> assign(:mode, mode)
    |> assign(:messages, messages)
    |> add_breadcrumb(name: "Show: #{user.name}", url: Routes.ts_admin_user_path(conn, :show, id))
    |> add_breadcrumb(name: "Chat logs", url: conn.request_path)
    |> render("full_chat.html")
  end

  @spec relationships(Plug.Conn.t(), map) :: Plug.Conn.t()
  def relationships(conn, %{"id" => id}) do
    user = Account.get_user!(id)
    user_ids = (user.data["friends"] ++ user.data["friend_requests"] ++ user.data["ignored"])
      |> Enum.uniq

    lookup = Account.list_users(search: [id_in: user_ids])
    |> Map.new(fn u -> {u.id, u} end)

    conn
    |> assign(:user, user)
    |> assign(:lookup, lookup)
    |> add_breadcrumb(name: "Show: #{user.name}", url: Routes.ts_admin_user_path(conn, :show, id))
    |> add_breadcrumb(name: "Relationships", url: conn.request_path)
    |> render("relationships.html")
  end

  @spec set_stat(Plug.Conn.t(), map) :: Plug.Conn.t()
  def set_stat(conn, %{"userid" => userid, "key" => key, "value" => value}) do
    user = Account.get_user!(userid)

    Account.update_user_stat(user.id, %{key => value})

    conn
    |> put_flash(:success, "stat #{key} updated")
    |> redirect(to: Routes.ts_admin_user_path(conn, :show, user.id))
  end

  @spec search_defaults(Plug.Conn.t()) :: Map.t()
  defp search_defaults(_conn) do
    %{
      "limit" => 50
    }
  end
end
