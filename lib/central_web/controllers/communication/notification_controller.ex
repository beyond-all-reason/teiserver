defmodule CentralWeb.Communication.NotificationController do
  use CentralWeb, :controller
  alias Central.Communication

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

  def handle_test(conn, %{"anid" => anid}) do
    notification = Communication.get_notification!(anid)

    conn
    |> assign(:notification, notification)
    |> render("handle_test.html")
  end

  def quick_new(conn, %{"f" => params}) do
    Communication.notify(
      get_hash_id(params["user_id"]),
      %{
        title: params["title"],
        body: params["body"],
        icon: params["icon"],
        colour: params["colour"],
        redirect: params["url"]
      },
      3,
      false
    )

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Notification sent")
  end

  def admin(conn, _params) do
    notifications =
      Communication.list_notifications(
        search: [user_id: conn.user_id],
        order: ["Newest first"],
        joins: [:user],
        limit: 50
      )

    conn
    |> assign(:notifications, notifications)
    |> render("admin.html")
  end

  def delete_all(conn, _params) do
    Communication.delete_all_notifications(conn.user_id)

    conn
    |> redirect(to: Routes.communication_notification_path(conn, :index))
  end

  # def delete_expired(conn, _params) do
  #   Communication.delete_expired_notifications(conn.user_id)

  #   conn
  #   |> redirect(to: Routes.communication_notification_path(conn, :index))
  # end

  def mark_all(conn, _params) do
    Communication.mark_all_notification_as_read(conn.user_id)

    conn
    |> redirect(to: Routes.communication_notification_path(conn, :index))
  end
end
