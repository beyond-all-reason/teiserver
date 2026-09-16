defmodule TeiserverWeb.ModerationLive.User.Show do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.AuthLib
  alias Teiserver.Account.UserLib
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Logging.AuditLogQueries
  alias Teiserver.Repo
  alias TeiserverWeb.ModerationLive.UserComponents

  use TeiserverWeb, :live_view

  @tab1_default "details"
  @tab2_default "actions"

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"id" => id}, _url, socket) when is_connected?(socket) do
    user = Account.get_user(id)

    case UserLib.has_access(user, socket) do
      {true, _role} ->
        user
        |> UserLib.make_favourite()
        |> insert_recently(socket)

        socket
        |> assign(user: user, page_title: "User details: #{user.name}")
        |> switch_tab(@tab1_default, "1")
        |> switch_tab(@tab2_default, "2")
        |> set_user_alerts()
        |> noreply()

      _no_access ->
        socket
        |> put_flash(:error, "Unable to access this user")
        |> redirect(to: ~p"/moderation/users")
    end
  end

  def handle_params(_params, _url, socket) do
    socket
    |> assign(
      user: nil,
      page_title: "User details",
      alerts: [],
      tab1: "details",
      tab2: "actions"
    )
    |> noreply()
  end

  @impl LiveView
  def handle_event("switch-tab", %{"tab" => tab, "tabset" => tabset}, %Socket{} = socket) do
    socket
    |> switch_tab(tab, tabset)
    |> noreply()
  end

  defp set_user_alerts(%Socket{assigns: %{user: nil}} = socket), do: socket

  defp set_user_alerts(%Socket{assigns: %{user: user}} = socket) do
    mfa_warning? =
      AuthLib.mfa_required?() and AuthLib.contains_mfa_role?(user.roles) and
        not has_active_mfa?(user.id)

    restriction_alert =
      cond do
        Enum.member?(user.restrictions, "Permanently banned") ->
          {"alert-error", "This user is permanently banned"}

        Enum.member?(user.restrictions, "Login") ->
          {"alert-error", "This user is restricted from logging in"}

        Enum.member?(user.restrictions, "All lobbies") ->
          {"alert-error", "This user is restricted from all lobbies"}

        Enum.member?(user.restrictions, "All chat") ->
          {"alert-warning", "This user is restricted from chatting"}

        not Enum.empty?(user.restrictions) ->
          {"alert-warning alert-soft", "This user has a minor restriction of some sort"}

        true ->
          nil
      end

    alerts =
      [
        not is_nil(user.gdpr_forget_after) &&
          {"alert-error", "This user is set to be forgotten under the GDPR right to be forgotten"},
        mfa_warning? &&
          {"alert-warning", "User has an MFA blocked role but no active MFA"},
        restriction_alert
      ]
      |> Enum.reject(&is_nil/1)

    socket
    |> assign(alerts: alerts)
  end

  defp switch_tab(socket, "details", tabset) do
    socket
    |> assign_tabset("details", tabset)
  end

  defp switch_tab(socket, "actions", tabset) do
    socket
    |> assign_tabset("actions", tabset)
  end

  defp switch_tab(%Socket{assigns: %{user: user}} = socket, "audit", tabset) do
    audit_logs =
      AuditLogQueries.audit_logs()
      |> AuditLogQueries.where_subject_id(user.id)
      |> AuditLogQueries.load_user()
      |> AuditLogQueries.order_by_inserted_at(:desc)
      |> QueryHelpers.limit_query(50)
      |> Repo.all()

    socket
    |> assign_tabset("audit", tabset)
    |> stream(:audit_logs, audit_logs, reset: true)
  end

  defp assign_tabset(socket, tab, "1") do
    socket
    |> assign(tab1: tab)
  end

  defp assign_tabset(socket, tab, "2") do
    socket
    |> assign(tab2: tab)
  end
end
