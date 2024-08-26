defmodule Teiserver.OAuth.TokenQueries do
  use TeiserverWeb, :queries
  alias Teiserver.OAuth.{Application, Token}

  @doc """
  Return the db object corresponding to the given token.
  This doesn't validate anything, use the context function instead
  """
  def get_token(nil), do: nil

  def get_token(value) do
    base_query()
    |> where_token(value)
    |> preload(:application)
    |> preload(:owner)
    |> preload(:autohost)
    |> Repo.one()
  end

  def base_query() do
    from token in Token,
      as: :token
  end

  def where_token(query, value) do
    from e in query,
      where: e.value == ^value
  end

  def where_app_ids(query, app_ids) do
    from [token: token] in query,
      where: token.application_id in ^app_ids
  end

  def not_expired(query, as_at \\ nil) do
    as_at = as_at || DateTime.utc_now()

    from [token: token] in query,
      where: token.expires_at > ^as_at
  end

  def expired(query, as_at \\ nil) do
    as_at = as_at || DateTime.utc_now()

    from [token: token] in query,
      where: token.expires_at <= ^as_at
  end

  @doc """
  given a refresh token, deletes it and its potential associated token
  """
  def delete_refresh_token(token) do
    from(tok in Token, where: tok.id == ^token.id or tok.refresh_token_id == ^token.id)
    |> Repo.delete_all()
  end

  @spec count_per_apps([Application.id()], DateTime.t() | nil) :: %{
          Application.id() => non_neg_integer()
        }
  def count_per_apps(app_ids, as_at \\ nil) do
    query =
      base_query()
      |> not_expired(as_at)
      |> where_app_ids(app_ids)

    from([token: token] in query,
      group_by: token.application_id,
      select: {token.application_id, count(token.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end
end
