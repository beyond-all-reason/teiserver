defmodule Teiserver.Microblog.UserPreferenceQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Microblog.UserPreference

  # Queries
  @spec query_user_preferences(list) :: Ecto.Query.t()
  def query_user_preferences(args) do
    query = from(user_preferences in UserPreference)

    query
    |> do_where(user_id: args[:user_id])
    # |> do_where(args[:where])
    |> query_select(args[:select])
  end

  @spec do_where(Ecto.Query.t(), list | map | nil) :: Ecto.Query.t()
  defp do_where(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _where(query_acc, key, value)
    end)
  end

  @spec _where(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  defp _where(query, _, ""), do: query
  defp _where(query, _, nil), do: query

  defp _where(query, :user_id, id) do
    from user_preferences in query,
      where: user_preferences.user_id == ^id
  end
end
