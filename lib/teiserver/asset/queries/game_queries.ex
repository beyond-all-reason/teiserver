defmodule Teiserver.Asset.GameQueries do
  use TeiserverWeb, :queries

  alias Teiserver.Asset

  @spec get_games() :: [Asset.Game.t()]
  def get_games() do
    base_query() |> order_by() |> Repo.all()
  end

  @spec get_game([id: integer() | String.t()] | [name: String.t()]) :: Asset.Game.t() | nil
  def get_game(id: id), do: base_query() |> where_id(id) |> Repo.one()
  def get_game(name: name), do: base_query() |> where_name(name) |> Repo.one()

  defp base_query() do
    from game in Asset.Game, as: :game
  end

  defp order_by(query) do
    from game in query, order_by: [desc: game.id]
  end

  def where_id(query, id) do
    from game in query, where: game.id == ^id
  end

  def where_name(query, name) do
    from game in query, where: game.name == ^name
  end
end
