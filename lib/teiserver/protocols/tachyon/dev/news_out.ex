defmodule Teiserver.Protocols.Tachyon.Dev.NewsOut do
  alias Teiserver.Protocols.Tachyon

  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:get_latest_game_news, nil) do
    %{
      cmd: "s.news.get_latest_game_news",
      post: nil
    }
  end

  def do_reply(:get_latest_game_news, post) do
    %{
      cmd: "s.news.get_latest_game_news",
      post: Tachyon.convert_object(:blog_post, post)
    }
  end
end
