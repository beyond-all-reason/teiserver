defmodule TeiserverWeb.Account.ViewAsController do
  @moduledoc """
  Starts and stops "view as" sessions, see `Teiserver.Account.ViewAs`.
  Both actions are recorded in the audit log against the real user.
  """

  alias Teiserver.Account
  alias Teiserver.Account.ViewAs
  alias Teiserver.Logging.Helpers, as: LoggingHelpers

  use TeiserverWeb, :controller

  def start(%{assigns: %{real_user: %{}}} = conn, _params) do
    conn
    |> put_flash(:error, "Stop viewing as the current user before viewing as someone else.")
    |> redirect(to: ~p"/")
  end

  def start(conn, %{"user_id" => user_id}) do
    real_user = conn.assigns[:current_user]

    target =
      case ViewAs.parse_id(user_id) do
        nil -> nil
        id -> Account.get_user(id)
      end

    if ViewAs.can_view_as?(real_user, target) do
      LoggingHelpers.add_audit_log(real_user.id, ip(conn), "View as: start", %{
        target_user_id: target.id,
        target_user_name: target.name
      })

      conn
      |> put_session(ViewAs.session_key(), target.id)
      |> put_flash(:info, "Now viewing the site as #{target.name}")
      |> redirect(to: ~p"/")
    else
      reason = ViewAs.denial_reason(real_user, target) || "You cannot view the site as that user."

      conn
      |> put_flash(:error, reason)
      |> redirect(to: ~p"/")
    end
  end

  def stop(conn, _params) do
    case conn.assigns[:real_user] do
      nil ->
        :ok

      real_user ->
        LoggingHelpers.add_audit_log(real_user.id, ip(conn), "View as: stop", %{
          target_user_id: conn.assigns[:current_user] && conn.assigns[:current_user].id
        })
    end

    conn
    |> delete_session(ViewAs.session_key())
    |> put_flash(:info, "Stopped viewing as another user")
    |> redirect(to: ~p"/")
  end

  defp ip(conn), do: conn.remote_ip
end
