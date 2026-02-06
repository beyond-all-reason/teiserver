defmodule Teiserver.OAuth.TokenQueries do
  use TeiserverWeb, :queries
  alias Teiserver.OAuth.{Application, Token, TokenHash}

  @doc """
  Return the token for the given value. Doesn't validate expiry.
  """
  def get_token(nil), do: nil

  def get_token(value) when is_binary(value) do
    case TokenHash.parse_token(value) do
      {:ok, {selector, verifier}} -> get_token_by_selector_and_verify(selector, verifier)
      :error -> nil
    end
  end

  defp get_token_by_selector_and_verify(selector, verifier) do
    token =
      base_query()
      |> where_selector(selector)
      |> preload(:application)
      |> preload(:owner)
      |> preload(:bot)
      |> Repo.one()

    case token do
      nil ->
        TokenHash.hash_verifier(verifier)
        nil

      token ->
        if TokenHash.verify_verifier(verifier, token.hashed_verifier), do: token, else: nil
    end
  end

  def base_query() do
    from token in Token,
      as: :token
  end

  def where_selector(query, selector) do
    from e in query, where: e.selector == ^selector
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
