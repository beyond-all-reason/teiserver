defmodule CentralWeb.Admin.ToolControllerTest do
  use CentralWeb.ConnCase, async: true

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(~w(admin.dev))
  end

  @coverage_string """
  COV    FILE                                                            LINES RELEVANT   MISSED
  100.0% lib/central/application.ex                                         72       22        0
    0.0% lib/central/coherence/invitation.ex                                40        3        3
    0.0% lib/central/coherence/rememberable.ex                              44        3        3
    0.0% lib/central/coherence/schemas.ex                                  141       31       31
    0.0% lib/central/coherence/user.ex                                      30        3        3
  100.0% lib/central/repo.ex                                                 3        0        0
    0.0% lib/central_web.ex                                                174        1        1
   92.3% lib/central_web/acl/lib/auth_groups_lib.ex                         52       13        1
   92.0% lib/central_web/acl/lib/authorisation_plug.ex                     125       25        2
   44.4% lib/central_web/acl/lib/limiter_plug.ex                            37        9        5
  100.0% lib/central_web/acl/otp/groups/server.ex                           37        5        0
  100.0% lib/central_web/acl/views/view_helpers.ex                           3        0        0
    0.0% lib/central_web/admin/helpers/general_helper.ex                     6        1        1
    0.0% lib/central_web/admin/views/general_view.ex                        18        6        6
    0.0% lib/central_web/communications/auth/communications_auth.ex                    9        2        2
    0.0% lib/central_web/communications/auth/category_auth.ex                     5        1        1
  100.0% lib/central_web/communications/auth/general_auth.ex                      7        0        0
    0.0% lib/central_web/communications/auth/post_auth.ex                         9        1        1
    0.0% lib/central_web/communications/channels/notification_channel.ex         50        1        1
    0.0% lib/central_web/communications/controllers/category_controller.ex      251       49       49
  100.0% lib/central_web/completed/controllers/completed_controller.ex      251       251       0
  """

  test "show tool index", %{conn: conn} do
    conn = get(conn, Routes.admin_tool_path(conn, :index))
    assert html_response(conn, 200) =~ "Test errors"
  end

  test "show developer test page", %{conn: conn} do
    conn = get(conn, Routes.admin_tool_path(conn, :test_page))
    assert html_response(conn, 200) =~ "Test page"
  end

  test "generate test error", %{conn: conn} do
    assert_raise ArithmeticError,
                 fn -> get(conn, Routes.admin_tool_path(conn, :test_error)) end
  end

  test "show the coverage form", %{conn: conn} do
    conn = get(conn, Routes.admin_tool_path(conn, :coverage_form))
    assert html_response(conn, 200) =~ "Coverage parser"
  end

  test "parse coverage data", %{conn: conn} do
    conn = post(conn, Routes.admin_tool_path(conn, :coverage_post), %{results: @coverage_string})
    assert html_response(conn, 200) =~ "Headline stats"
  end

  test "show oban dashboard", %{conn: conn} do
    conn = get(conn, Routes.admin_tool_path(conn, :oban_dashboard))
    assert html_response(conn, 200) =~ "Scheduled jobs"
  end

  test "parse conn params", %{conn: conn} do
    conn = get(conn, Routes.admin_tool_path(conn, :conn_params))
    assert html_response(conn, 200) =~ "Connection parameters"
  end
end
