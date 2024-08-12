defmodule Teiserver.AutohostQueries do
  use TeiserverWeb, :queries
  alias Teiserver.Autohost.Autohost

  @spec get_autohost(Autohost.id()) :: Autohost.t() | nil
  def get_autohost(nil), do: nil

  def get_autohost(id) do
    base_query() |> where_id(id) |> Repo.one()
  end

  def base_query() do
    from autohost in Autohost, as: :autohost
  end

  def where_id(query, id) do
    from autohost in query,
      where: autohost.id == ^id
  end
end
