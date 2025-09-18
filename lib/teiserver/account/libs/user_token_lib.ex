defmodule Teiserver.Account.UserTokenLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Account.UserToken

  @spec colours :: atom
  def colours(), do: :info

  @spec icon :: String.t()
  def icon(), do: "fa-solid fa-hexagon-check"

  # Queries
  @spec query_user_tokens() :: Ecto.Query.t()
  def query_user_tokens do
    from(user_tokens in UserToken)
  end

  @spec search(Ecto.Query.t(), map | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom, any) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from user_tokens in query,
      where: user_tokens.id == ^id
  end

  def _search(query, :value, value) do
    from user_tokens in query,
      where: user_tokens.value == ^value
  end

  def _search(query, :id_list, id_list) do
    from user_tokens in query,
      where: user_tokens.id in ^id_list
  end

  def _search(query, :user_id, user_id) do
    from user_tokens in query,
      where: user_tokens.user_id == ^user_id
  end

  def _search(query, :expired, false) do
    from user_tokens in query,
      where: user_tokens.expires > ^Timex.now()
  end

  def _search(query, :expired, true) do
    from user_tokens in query,
      where: user_tokens.expires < ^Timex.now()
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Most recently used") do
    from user_tokens in query,
      order_by: [desc: user_tokens.last_used]
  end

  def order_by(query, "Least recently used") do
    from user_tokens in query,
      order_by: [asc: user_tokens.last_used]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_user(query), else: query
    query
  end

  @spec _preload_user(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_user(query) do
    from user_tokens in query,
      left_join: users in assoc(user_tokens, :user),
      preload: [user: users]
  end
end
