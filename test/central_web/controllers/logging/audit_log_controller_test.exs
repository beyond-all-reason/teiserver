defmodule CentralWeb.Logging.AuditLogControllerTest do
  use CentralWeb.ConnCase, async: true

  # alias CentralWeb.Logging.AuditLog
  alias Central.Logging.Helpers
  # @valid_attrs %{action: "some content", details: "{}", ip: "some content"}
  # @invalid_attrs %{}

  alias Central.Helpers.GeneralTestLib
  alias Central.Logging.LoggingTestLib

  setup do
    GeneralTestLib.conn_setup(~w(logging.audit.show))
    |> LoggingTestLib.logging_setup()
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get(conn, Routes.logging_audit_log_path(conn, :index))
    assert html_response(conn, 200) =~ "Audit logs"
  end

  test "searches logs", %{conn: conn, user: user} do
    conn =
      post(conn, Routes.logging_audit_log_path(conn, :search),
        search: %{
          name: "Test",
          action: "Bedrock object import",
          central_user: "##{user.id}"
        }
      )

    assert html_response(conn, 200) =~ "Audit logs"
  end

  test "searches logs (empty values)", %{conn: conn} do
    conn =
      post(conn, Routes.logging_audit_log_path(conn, :search),
        search: %{
          name: "",
          action: "All",
          central_user: ""
        }
      )

    assert html_response(conn, 200) =~ "Audit logs"
  end

  test "shows chosen resource", %{conn: conn} do
    # We need to call a path first because currently the conn has
    # no current_user assigned
    conn = get(conn, Routes.logging_audit_log_path(conn, :index))
    audit_log = Helpers.add_audit_log(conn, "action", %{})

    conn = get(conn, Routes.logging_audit_log_path(conn, :show, audit_log))
    assert html_response(conn, 200) =~ "Audit log ##{audit_log.id}"
  end
end
