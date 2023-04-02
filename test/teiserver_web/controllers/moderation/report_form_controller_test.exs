defmodule TeiserverWeb.Moderation.ReportFormControllerTest do
  @moduledoc false
  use CentralWeb.ConnCase

  alias Teiserver.Moderation

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(["teiserver"])
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  describe "index" do
    test "lists all reports", %{conn: conn} do
      user = GeneralTestLib.make_user()
      conn = get(conn, Routes.moderation_report_form_path(conn, :index, user.id))
      assert html_response(conn, 200) =~ "User report form: #{user.name}"
      assert html_response(conn, 200) =~ "Reason for report"
    end
  end

  describe "submit" do
    test "success", %{conn: conn} do
      user = GeneralTestLib.make_user()
      assert Enum.empty?(Moderation.list_reports(search: [target_id: user.id]))

      attrs = %{
        "target_id" => user.id,
        "type" => "type",
        "sub_type" => "sub_type"
      }

      conn = post(conn, Routes.moderation_report_form_path(conn, :create), report: attrs)
      assert redirected_to(conn) == Routes.moderation_report_form_path(conn, :success)

      assert Enum.count(Moderation.list_reports(search: [target_id: user.id])) == 1
    end
  end
end
