defmodule Teiserver.Account.RetentionReportTest do
  @moduledoc false
  alias Teiserver.Account.RetentionReport
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Logging

  use Teiserver.DataCase, async: false

  describe "run/2" do
    test "does not raise for verified players with recorded activity" do
      user =
        GeneralTestLib.make_user(%{
          "roles" => ["Verified"],
          "data" => %{"last_login_mins" => 60}
        })

      # last_login is a DateTime while inserted_at is a NaiveDateTime; the report
      # has to reconcile these types when computing day offsets. Previously this
      # combination raised a FunctionClauseError in DateTime.diff/3 and returned
      # a 500 for the page.
      {:ok, user} =
        user
        |> change(last_login: DateTime.utc_now(:second))
        |> Repo.update()

      {:ok, _log} =
        Logging.create_user_activity_day_log(%{
          date: Date.utc_today(),
          data: %{"player" => %{to_string(user.id) => 30}}
        })

      result = RetentionReport.run(nil, %{})

      assert result.user_count == 1
      assert [["Login" | _login], ["Play" | _play]] = result.graph_data
    end

    test "runs with no matching players" do
      result = RetentionReport.run(nil, %{})

      assert result.user_count == 0
      assert [["Login" | _login], ["Play" | _play]] = result.graph_data
    end
  end
end
