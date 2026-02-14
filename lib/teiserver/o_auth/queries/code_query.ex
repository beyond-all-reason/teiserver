defmodule Teiserver.OAuth.CodeQueries do
  use TeiserverWeb, :queries
  alias Teiserver.OAuth.{Application, Code, TokenHash}

  @spec get_code(String.t() | nil) :: Code.t() | nil
  def get_code(nil), do: nil

  def get_code(value) when is_binary(value) do
    case TokenHash.parse_token(value) do
      {:ok, {selector, verifier}} -> get_code_by_selector_and_verify(selector, verifier)
      :error -> nil
    end
  end

  defp get_code_by_selector_and_verify(selector, verifier) do
    code =
      base_query()
      |> where_selector(selector)
      |> Repo.one()

    case code do
      nil ->
        TokenHash.hash_verifier(verifier)
        nil

      code ->
        if TokenHash.verify_verifier(verifier, code.hashed_verifier), do: code, else: nil
    end
  end

  def base_query(), do: from(code in Code, as: :code)

  def where_selector(query, selector), do: from(e in query, where: e.selector == ^selector)

  def where_app_ids(query, app_ids) do
    from [code: code] in query,
      where: code.application_id in ^app_ids
  end

  def not_expired(query, as_at \\ nil) do
    as_at = as_at || DateTime.utc_now()

    from [code: code] in query,
      where: code.expires_at > ^as_at
  end

  def expired(query, as_at \\ nil) do
    as_at = as_at || DateTime.utc_now()

    from [code: code] in query,
      where: code.expires_at <= ^as_at
  end

  @spec count_per_apps([Application.id()], DateTime.t() | nil) :: %{
          Application.id() => non_neg_integer()
        }
  def count_per_apps(app_ids, as_at \\ nil) do
    query =
      base_query()
      |> not_expired(as_at)
      |> where_app_ids(app_ids)

    from([code: code] in query,
      group_by: code.application_id,
      select: {code.application_id, count(code.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end
end
