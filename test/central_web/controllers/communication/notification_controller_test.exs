defmodule CentralWeb.Communication.NotificationControllerTest do
  use CentralWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup()
  end

  alias Central.Communication

  # @valid_attrs %{body: "some content", data: %{}, expires: %{day: 17, hour: 14, min: 0, month: 4, sec: 0, year: 2010}, icon: "some content", colour: "some content", redirect: "some content", read: true, title: "some content", user_id: 42, expired: false}
  # @invalid_attrs %{}

  test "lists all entries on index", %{conn: conn} do
    conn = get(conn, Routes.communication_notification_path(conn, :index))
    assert html_response(conn, 200) =~ "Notifications"
  end

  test "deletes chosen resource", %{conn: conn, user: user} do
    [notification] =
      Communication.notify(
        user.id,
        %{
          title: "Test notification",
          body: "This is a test notification",
          icon: "fa-lightbulb-o",
          colour: "#08C",
          redirect: Routes.communication_notification_path(conn, :handle_test)
        },
        3,
        true
      )

    conn = delete(conn, Routes.communication_notification_path(conn, :delete, notification))
    assert redirected_to(conn) == Routes.communication_notification_path(conn, :index)

    notifications =
      user.id
      |> Communication.list_user_notifications()

    assert Enum.count(notifications) == 0
  end

  test "create test notififcation", %{conn: conn, user: user} do
    # No pre-existing notifications
    notifications =
      user.id
      |> Communication.list_user_notifications()

    assert Enum.count(notifications) == 0

    conn =
      post(conn, Routes.communication_notification_path(conn, :quick_new),
        f: %{
          "user_id" => "##{user.id}",
          "title" => "title",
          "body" => "body",
          "icon" => "icon",
          "colour" => "colour",
          "url" => "url"
        }
      )

    assert response(conn, 200) == "Notification sent"

    # Check it got added
    notifications =
      user.id
      |> Communication.list_user_notifications()

    assert Enum.count(notifications) == 1
  end

  test "handle test notififcation", %{conn: conn, user: user} do
    Communication.notify(
      user.id,
      %{
        title: "Test notification",
        body: "This is a test notification",
        icon: "fa-lightbulb-o",
        colour: "#08C",
        redirect: Routes.communication_notification_path(conn, :handle_test)
      },
      3,
      true
    )

    Communication.notify(
      user.id,
      %{
        title: "Test notification",
        body: "This is a test notification",
        icon: "fa-lightbulb-o",
        colour: "#08C",
        redirect: Routes.communication_notification_path(conn, :handle_test)
      },
      3,
      true
    )

    Communication.notify(
      user.id,
      %{
        title: "Test notification",
        body: "This is a test notification",
        icon: "fa-lightbulb-o",
        colour: "#08C",
        redirect: Routes.communication_notification_path(conn, :handle_test)
      },
      3,
      false
    )

    # Check it got added
    notifications =
      user.id
      |> Communication.list_user_notifications(:unread)

    # It should be 2 not 3 as one is a duplicate that's checked for
    assert Enum.count(notifications) == 2

    notification = hd(notifications)

    # Now to access the test page
    conn = get(conn, notification.redirect <> "?anid=#{notification.id}")
    assert html_response(conn, 200) =~ "Test notification ##{notification.id}"

    # Ensure one was marked as read as a result of this
    notifications =
      user.id
      |> Communication.list_user_notifications(:unread)

    assert Enum.count(notifications) == 1
  end

  test "delete all", %{conn: conn, user: user} do
    # Check we have no notifications prior to starting this
    notifications =
      user.id
      |> Communication.list_user_notifications()

    assert notifications == []

    Communication.notify(
      user.id,
      %{title: "title", body: "body", icon: "icon", colour: "colour", redirect: "redirect"},
      3,
      false
    )

    Communication.notify(
      user.id,
      %{title: "title", body: "body", icon: "icon", colour: "colour", redirect: "redirect"},
      -5,
      false
    )

    # Check they got added
    notifications =
      user.id
      |> Communication.list_user_notifications()

    assert Enum.count(notifications) == 2

    # Delete all
    conn = get(conn, Routes.communication_notification_path(conn, :delete_all))
    assert redirected_to(conn) == Routes.communication_notification_path(conn, :index)

    notifications =
      user.id
      |> Communication.list_user_notifications()

    assert Enum.count(notifications) == 0
  end

  test "mark all as read", %{conn: conn, user: user} do
    notifications =
      user.id
      |> Communication.list_user_notifications()

    assert notifications == []

    Communication.notify(
      user.id,
      %{title: "title", body: "body", icon: "icon", colour: "colour", redirect: "redirect"},
      3,
      false
    )

    Communication.notify(
      user.id,
      %{title: "title", body: "body", icon: "icon", colour: "colour", redirect: "redirect"},
      -5,
      false
    )

    # Check they got added
    notifications =
      user.id
      |> Communication.list_user_notifications()

    assert Enum.count(notifications) == 2

    # Check we only find 1 of them
    notifications =
      user.id
      |> Communication.list_user_notifications(:unread)

    assert Enum.count(notifications) == 1

    # Mark all as read
    conn = get(conn, Routes.communication_notification_path(conn, :mark_all))
    assert redirected_to(conn) == Routes.communication_notification_path(conn, :index)

    # They should still be there
    notifications =
      user.id
      |> Communication.list_user_notifications()

    assert Enum.count(notifications) == 2

    # But not here
    notifications =
      user.id
      |> Communication.list_user_notifications(:unread)

    assert notifications == []
  end
end
