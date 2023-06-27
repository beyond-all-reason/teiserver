defmodule TeiserverWeb.Communication.NotificationController do
  use CentralWeb, :controller
  alias Teiserver.Communication

  plug :add_breadcrumb, name: 'Notifications', url: '/communication/notifications'

  def index(conn, _params) do
    notifications =
      Communication.list_notifications(
        search: [user_id: conn.user_id],
        order: ["Newest first"],
        limit: 50
      )

    conn
    |> assign(:notifications, notifications)
    |> render("index.html")
  end

  def delete(conn, %{"id" => id}) do
    notification = Communication.get_notification!(id)
    Communication.delete_notification(notification)

    conn
    |> put_flash(:info, "Notification deleted successfully.")
    |> redirect(to: Routes.communication_notification_path(conn, :index))
  end

  def delete_all(conn, _params) do
    Communication.delete_all_notifications(conn.user_id)

    conn
    |> redirect(to: Routes.communication_notification_path(conn, :index))
  end

  def mark_all(conn, _params) do
    Communication.mark_all_notification_as_read(conn.user_id)

    conn
    |> redirect(to: Routes.communication_notification_path(conn, :index))
  end
end
