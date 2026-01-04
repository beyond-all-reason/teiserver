defmodule Teiserver.OAuth.CodeQueries do
  use TeiserverWeb, :queries
  alias Teiserver.OAuth.Application
  alias Teiserver.OAuth.Code

  @doc """
  Return the db object corresponding to the given code.
  This doesn't validate anything, use the context function instead
  """
  @spec get_code(String.t() | nil) :: Code.t() | nil
  def get_code(nil), do: nil

  def get_code(code) do
    base_query() |> where_code(code) |> Repo.one()
  end

  def base_query() do
    from code in Code, as: :code
  end

  def where_code(query, value) do
    hashed_value = Teiserver.Helper.HashHelper.hash_with_fixed_salt(value)

    from e in query,
      where: e.value == ^hashed_value
  end

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
