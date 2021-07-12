defmodule Central.Communication.NotificationPlug do
  import Plug.Conn
  alias Central.Communication

  def init(_opts) do
    # %{}
  end

  def call(%{user_id: nil} = conn, _) do
    conn
    |> assign(:user_notifications, [])
    |> assign(:user_notifications_unread_count, 0)
  end

  def call(conn, _ops) do
    if conn.params["anid"] do
      Communication.mark_notification_as_read(conn.assigns[:current_user].id, conn.params["anid"])
    end

    assign_notificiations(conn, conn.assigns[:current_user])
  end

  def live_call(socket) do
    notifications =
      socket.assigns.user_id
      |> Communication.list_user_notifications(:unread)

    unread_count =
      notifications
      |> Enum.filter(fn n ->
        not n.read
      end)
      |> Enum.count()

    socket
    |> Phoenix.LiveView.assign(:user_notifications, notifications)
    |> Phoenix.LiveView.assign(:user_notifications_unread_count, unread_count)
  end

  defp assign_notificiations(conn, nil) do
    conn
    |> assign(:user_notifications, [])
  end

  defp assign_notificiations(conn, the_user) do
    notifications =
      the_user.id
      |> Communication.list_user_notifications(:unread)

    unread_count =
      notifications
      |> Enum.filter(fn n ->
        not n.read
      end)
      |> Enum.count()

    conn
    |> assign(:user_notifications, notifications)
    |> assign(:user_notifications_unread_count, unread_count)
  end
end
