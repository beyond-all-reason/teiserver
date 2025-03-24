defmodule Teiserver.Asset.GameQueries do
  use TeiserverWeb, :queries

  alias Teiserver.Asset

  @spec get_games() :: [Asset.Game.t()]
  def get_games() do
    base_query() |> Repo.all()
  end

  defp base_query() do
    from game in Asset.Game, as: :game
  end
end
