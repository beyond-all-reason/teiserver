defmodule Teiserver.BotQueries do
  use TeiserverWeb, :queries
  alias Teiserver.Bot.Bot

  @doc """
  Returns all bots.
  That list may get big, so think about streaming and/or paginating
  but for now this will do.
  """
  @spec list_bots() :: [Bot.t()]
  def list_bots() do
    base_query() |> Repo.all()
  end

  @spec get_by_id(Bot.id()) :: Bot.t() | nil
  def get_by_id(nil), do: nil

  def get_by_id(id) do
    base_query() |> where_id(id) |> Repo.one()
  end

  def base_query() do
    from bot in Bot, as: :bot
  end

  def where_id(query, id) do
    from bot in query,
      where: bot.id == ^id
  end
end
