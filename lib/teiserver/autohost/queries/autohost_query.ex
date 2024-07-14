defmodule Teiserver.AutohostQueries do
  use TeiserverWeb, :queries
  alias Teiserver.Autohost.Autohost

  @doc """
  Returns all autohosts.
  That list may get big, so think about streaming and/or paginating
  but for now this will do.
  """
  @spec list_autohosts() :: [Autohost.t()]
  def list_autohosts() do
    base_query() |> Repo.all()
  end

  @spec get_by_id(Autohost.id()) :: Autohost.t() | nil
  def get_by_id(nil), do: nil

  def get_by_id(id) do
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
