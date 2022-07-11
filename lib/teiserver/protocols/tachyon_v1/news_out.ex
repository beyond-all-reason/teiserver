defmodule Teiserver.Protocols.Tachyon.V1.NewsOut do
  alias Teiserver.Protocols.Tachyon.V1.Tachyon

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
      post: Tachyon.convert_object(post, :blog_post)
    }
  end
end
