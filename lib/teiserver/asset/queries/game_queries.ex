defmodule Teiserver.Asset.GameQueries do
  use TeiserverWeb, :queries

  alias Teiserver.Asset

  @spec get_games() :: [Asset.Game.t()]
  def get_games() do
    base_query() |> order_by() |> Repo.all()
  end

  @type where_opt ::
          {:id, integer() | String.t()} | {:name, String.t()} | {:in_matchmaking, boolean()}
  @type where_opts :: [where_opt()]

  @spec get_game(where_opts()) :: Asset.Game.t() | nil
  def get_game(clauses) do
    Enum.reduce(clauses, base_query(), fn clause, q ->
      case clause do
        {:id, id} -> where_id(q, id)
        {:name, name} -> where_name(q, name)
        {:in_matchmaking, mm} -> where_in_matchmaking(q, mm)
      end
    end)
    |> Repo.one()
  end

  @doc """
  When creating a lobby, use this game version.
  """
  @spec get_default_lobby_game() :: Asset.Game.t() | nil
  def get_default_lobby_game() do
    # for now, just return the same game as for matchmaking
    get_game(in_matchmaking: true)
  end

  defp base_query() do
    from game in Asset.Game, as: :game
  end

  defp order_by(query) do
    from game in query, order_by: [desc: game.id]
  end

  def where_id(query, nil), do: from(game in query, where: is_nil(game.id))
  def where_id(query, id), do: from(game in query, where: game.id == ^id)

  def where_name(query, name) do
    from game in query, where: game.name == ^name
  end

  def where_in_matchmaking(query, mm) do
    from game in query, where: game.in_matchmaking == ^mm
  end
end
