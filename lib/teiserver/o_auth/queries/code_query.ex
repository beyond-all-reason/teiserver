defmodule Teiserver.OAuth.CodeQueries do
  use TeiserverWeb, :queries
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
    from e in query,
      where: e.value == ^value
  end
end
