defmodule Teiserver.Protocols.Tachyon.V1.NewsIn do
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  alias Teiserver.Communication

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("get_latest_game_news", %{"category" => category_name}, state) do
    case Communication.get_category_id(category_name) do
      nil ->
        reply(:news, :get_latest_game_news, nil, state)

      category_id ->
        latest_post = Communication.get_latest_post(category_id)
        reply(:news, :get_latest_game_news, latest_post, state)
    end
  end
end
