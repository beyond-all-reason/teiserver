defmodule TeiserverWeb.Account.RelationshipLive.IndexLiveTest do
  use TeiserverWeb.ConnCase, async: true
  alias TeiserverWeb.Account.RelationshipLive.Index
  alias Central.Helpers.GeneralTestLib

  test "account relationship endpoints requires authentication" do
    {:ok, kw} =
      GeneralTestLib.conn_setup([], [:no_login])
      |> Teiserver.TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)

    conn = get(conn, ~p"/account/relationship")
    assert redirected_to(conn) == ~p"/login"
  end

  test "can access account relationship when authenticated" do
    {:ok, kw} =
      GeneralTestLib.conn_setup()
      |> Teiserver.TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)

    conn = get(conn, ~p"/account/relationship")
    html_response(conn, 200)
  end

  test "purge cutoff options are valid" do
    options = Index.get_purge_cutoff_options()
    assert length(options) > 0

    default_option = Index.get_default_purge_cutoff_option()
    assert Enum.member?(options, default_option)

    Enum.map(options, fn option ->
      assert is_number(Index.get_purge_days_cutoff(option))
    end)
  end

  test "get_purge_days_cutoff returns error" do
    assert Index.get_purge_days_cutoff("20 days") == {:error, "invalid duration passed: 20 days"}

    assert Index.get_purge_days_cutoff("x months") ==
             {:error, "invalid duration passed: x months"}
  end

  test "get_days_diff works" do
    now = Timex.now()
    other_date = DateTime.add(now, -400, :day)
    result = Index.get_days_diff(now, other_date)
    assert result == 400

    other_date = nil
    result = Index.get_days_diff(now, other_date)
    assert result == 0
  end
end
