defmodule TeiserverWeb.Battle.MatchLive.ChatLiveTest do
  use TeiserverWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Central.Helpers.GeneralTestLib

  setup do
    {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"], [:no_login])

    {:ok, user} = Keyword.fetch(kw, :user)

    battle =
      Teiserver.TeiserverTestLib.make_battle(%{
        name: "LiveBattle",
        founder_id: user.id,
        founder_name: user.name
      })

    {:ok, kw ++ [battle: battle]}
  end

  test "battle chat endpoints requires authentication", %{conn: conn, battle: battle} do
    conn = get(conn, ~p"/battle/chat/#{battle.id}")
    assert redirected_to(conn) == ~p"/login"
  end

  test "can access battle chat when authenticated", %{conn: conn, battle: battle, user: user} do
    conn = GeneralTestLib.login(conn, user.email)
    conn = get(conn, ~p"/battle/chat/#{battle.id}")
    html_response(conn, 200)
  end

  test "unauthorized user cannot access battle chat", %{conn: conn, battle: battle} do
    user = GeneralTestLib.make_user()
    conn = GeneralTestLib.login(conn, user.email)
    conn = get(conn, ~p"/battle/chat/#{battle.id}")
    assert redirected_to(conn) == ~p"/"
  end
end
