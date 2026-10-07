defmodule TeiserverWeb.ModerationLive.User.Show do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.AuthLib
  alias Teiserver.Account.UserCacheLib
  alias Teiserver.Account.UserLib
  alias Teiserver.Account.UserNote
  alias Teiserver.Account.UserNoteQueries
  alias Teiserver.Account.UserQueries
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Logging.AuditLogQueries
  alias TeiserverWeb.ModerationLive.User.FormEmailComponent
  alias TeiserverWeb.ModerationLive.User.FormNameComponent
  alias TeiserverWeb.ModerationLive.User.UserNoteFormComponent
  alias TeiserverWeb.ModerationLive.UserComponents

  use TeiserverWeb, :live_view

  import Teiserver.Logging.Helpers, only: [add_audit_log: 3]

  @tab1_default "details"
  @tab2_default "actions"

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"id" => id} = params, _url, socket) when is_connected?(socket) do
    user =
      UserQueries.users()
      |> UserQueries.where_id(id)
      |> UserQueries.load_user_stat()
      |> Repo.one()

    if UserLib.can_access_user?(user, socket.assigns.scope) do
      user
      |> UserLib.make_favourite()
      |> insert_recently(socket)

      socket
      |> assign(user: user, page_title: "User details: #{user.name}", user_id: id)
      |> switch_tab(@tab1_default, "1")
      |> switch_tab(@tab2_default, "2")
      |> set_user_alerts()
      |> apply_action(socket.assigns.live_action, params)
      |> noreply()
    else
      if user do
        add_audit_log(socket.assigns.scope, "User access attempt", %{
          user_id: user && user.id,
          page: "gdpr_restore/perform"
        })
      end

      socket
      |> put_flash(:error, "Unable to access this user")
      |> redirect(to: ~p"/moderation/users")
      |> noreply()
    end
  end

  def handle_params(%{"id" => id}, _url, socket) do
    socket
    |> assign(
      user: nil,
      page_title: "User details",
      alerts: [],
      tab1: "details",
      tab2: "actions",
      user_id: id
    )
    |> noreply()
  end

  @impl LiveView
  def handle_event("switch-tab", %{"tab" => tab, "tabset" => tabset}, %Socket{} = socket) do
    socket
    |> switch_tab(tab, tabset)
    |> noreply()
  end

  def handle_event(
        "delete-user_note",
        %{"user_note_id" => user_note_id},
        %Socket{assigns: assigns} = socket
      ) do
    %{scope: scope} = assigns
    user_note = Account.get_user_note!(user_note_id)

    allowed? = user_note.creator_id == assigns.scope.user.id or allow?(assigns.scope, "Admin")

    result =
      Repo.transact(fn ->
        with true <- allowed?,
             {:ok, _user_note} <- Account.delete_user_note(user_note),
             %{} <-
               add_audit_log(scope, "Delete UserNote", %{
                 user_note_id: user_note.id,
                 user_id: user_note.user_id
               }) do
          {:ok, :success}
        else
          _error -> {:error, :error}
        end
      end)

    case result do
      {:ok, :success} ->
        socket
        |> redirect(to: ~p"/moderation/users/#{user_note.user_id}")
        |> put_flash(:success, "User note deleted")
        |> switch_tab("notes", nil)
        |> noreply()

      {:error, _error} ->
        socket
        |> put_flash(:error, "Unable to delete user note")
        |> noreply()
    end

    socket
    |> noreply()
  end

  defp set_user_alerts(%Socket{assigns: %{user: nil}} = socket), do: socket

  defp set_user_alerts(%Socket{assigns: %{user: user}} = socket) do
    mfa_warning? =
      AuthLib.mfa_required?() and AuthLib.contains_mfa_role?(user.roles) and
        not has_active_mfa?(user.id)

    restriction_alert =
      cond do
        # If they are anonymised then we will not alert for any restrictions
        Enum.member?(user.roles, "GDPR forgotten") ->
          nil

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

    email_alert =
      if UserLib.days_since_last_email_change(user) < 14 do
        {"alert-warning", "Email changed within the last 14 days"}
      end

    alerts =
      [
        Enum.member?(user.roles, "GDPR forgotten") &&
          {"alert-error", "This user has been GDPR anonymised"},
        not is_nil(user.gdpr_forget_after) &&
          {"alert-error", "This user is set to be forgotten under the GDPR right to be forgotten"},
        mfa_warning? &&
          {"alert-warning", "User has an MFA blocked role but no active MFA"},
        restriction_alert,
        email_alert
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

  defp switch_tab(%Socket{assigns: assigns} = socket, "raw", tabset) do
    cache_user = UserCacheLib.deprecated_get_user_by_id(assigns.user.id)

    socket
    |> assign(cache_user: cache_user)
    |> assign_tabset("raw", tabset)
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

  defp switch_tab(%Socket{assigns: %{user: user}} = socket, "notes", tabset) do
    user_notes =
      UserNoteQueries.user_notes()
      |> UserNoteQueries.where_user_id(user.id)
      |> UserNoteQueries.load_creator()
      |> UserNoteQueries.order_by_inserted_at(:desc)
      |> QueryHelpers.limit_query(100)
      |> Repo.all()

    socket
    |> assign_tabset("notes", tabset)
    |> stream(:user_notes, user_notes, reset: true)
  end

  defp assign_tabset(socket, tab, "1") do
    socket
    |> assign(tab1: tab)
  end

  defp assign_tabset(socket, tab, "2") do
    socket
    |> assign(tab2: tab)
  end

  defp assign_tabset(socket, _tab, nil) do
    socket
  end

  defp apply_action(%Socket{} = socket, :edit_note, %{"user_note_id" => user_note_id}) do
    user_note = Account.get_user_note!(user_note_id)
    %{user: user, scope: scope} = socket.assigns

    cond do
      user_note.user_id != user.id ->
        socket
        |> redirect(to: ~p"/moderation/users/#{user.id}")

      user_note.creator_id != scope.user.id and not allow?(scope, "Admin") ->
        socket
        |> redirect(to: ~p"/moderation/users/#{user.id}")

      true ->
        socket
        |> assign(:page_title, "Edit user note")
        |> assign(:user_note, user_note)
    end
  end

  defp apply_action(%Socket{} = socket, :new_note, _params) do
    socket
    |> assign(:page_title, "New user note")
    |> assign(:user_note, %UserNote{})
  end

  defp apply_action(%Socket{} = socket, :edit_name, _params) do
    socket
    |> assign(:page_title, "Change user name")
  end

  defp apply_action(%Socket{} = socket, :edit_email, _params) do
    socket
    |> assign(:page_title, "Change user email")
  end

  defp apply_action(%Socket{} = socket, _any, _params), do: socket
end
