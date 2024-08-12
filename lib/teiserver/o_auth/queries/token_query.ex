defmodule Teiserver.OAuth.TokenQueries do
  use TeiserverWeb, :queries
  alias Teiserver.OAuth.Token

  @doc """
  Return the db object corresponding to the given token.
  This doesn't validate anything, use the context function instead
  """
  def get_token(nil), do: nil

  def get_token(value) do
    base_query()
    |> where_token(value)
    |> preload(:application)
    |> Repo.one()
  end

  def base_query() do
    from token in Token,
      as: :token,
      preload: [refresh_token: token]
  end

  def where_token(query, value) do
    from e in query,
      where: e.value == ^value
  end

  @doc """
  given a refresh token, deletes it and its potential associated token
  """
  def delete_refresh_token(token) do
    from(tok in Token, where: tok.id == ^token.id or tok.refresh_token_id == ^token.id)
    |> Repo.delete_all()
  end
end
