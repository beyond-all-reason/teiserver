defmodule Teiserver.Protocols.TachyonNewsTest do
  alias Central.CommunicationTestLib
  alias Central.Helpers.GeneralTestLib
  use Central.ServerCase

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()
    {:ok, socket: socket, user: user, pid: pid}
  end

  test "no latest post", %{socket: socket} do
    data = %{cmd: "c.news.get_latest_game_news", category: "non-existant category"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)

    assert reply == %{"cmd" => "s.news.get_latest_game_news", "post" => nil}
  end

  test "latest post", %{socket: socket} do
    category = CommunicationTestLib.new_category(%{"name" => "GameNewsCategory"})
    post = CommunicationTestLib.new_post(%{
      "category_id" => category.id,
      "poster_id" => GeneralTestLib.make_user().id
    })

    data = %{cmd: "c.news.get_latest_game_news", category: "GameNewsCategory"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)

    assert match?(%{"cmd" => "s.news.get_latest_game_news"}, reply)
    assert reply["post"]["content"] == "content\ncontent"
    assert reply["post"]["short_content"] == "content"
    assert reply["post"]["tags"] == ["Tag 1", "Tag 2"]
  end
end
