defmodule Teiserver.Microblog.PollResponseQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Microblog.PollResponse
  alias Teiserver.Helper.QueryHelpers

  # Queries
  @spec query_poll_responses(list) :: Ecto.Query.t()
  def query_poll_responses(args) do
    query = from(poll_responses in PollResponse)

    query
    |> do_where(args[:where])
    |> query_select(args[:select])
    |> QueryHelpers.limit_query(args[:limit])
  end

  @spec do_where(Ecto.Query.t(), list | map | nil) :: Ecto.Query.t()
  defp do_where(query, nil), do: query

  defp do_where(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _where(query_acc, key, value)
    end)
  end

  @spec _where(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  defp _where(query, _, ""), do: query
  defp _where(query, _, nil), do: query

  defp _where(query, :id, id) do
    from poll_responses in query,
      where: poll_responses.id == ^id
  end

  defp _where(query, :user_id, user_id) do
    from poll_responses in query,
      where: poll_responses.user_id in ^List.wrap(user_id)
  end

  defp _where(query, :post_id, post_id) do
    from poll_responses in query,
      where: poll_responses.post_id in ^List.wrap(post_id)
  end

  def responses_by_choice(post_id) do
    from poll_responses in PollResponse,
      where: poll_responses.post_id == ^post_id,
      group_by: poll_responses.response,
      select: {poll_responses.response, count(poll_responses.user_id)}
  end
end
