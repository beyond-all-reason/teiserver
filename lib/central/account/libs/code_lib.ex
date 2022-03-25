defmodule Central.Account.CodeLib do
  @moduledoc false
  use CentralWeb, :library
  alias Central.Account.Code

  @spec colours :: atom
  def colours(), do: :info

  @spec icon :: String.t()
  def icon(), do: "fa-regular fa-octagon"

  @doc """
  Returns a list of the code types we can manually use (e.g. not password_reset)
  """
  @spec code_types() :: [String.t()]
  def code_types() do
    ~w(
      one-time-login
      user_registration
    )
  end

  # Queries
  @spec query_codes() :: Ecto.Query.t()
  def query_codes do
    from(codes in Code)
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
    from codes in query,
      where: codes.id == ^id
  end

  def _search(query, :value, value) do
    from codes in query,
      where: codes.value == ^value
  end

  def _search(query, :id_list, id_list) do
    from codes in query,
      where: codes.id in ^id_list
  end

  def _search(query, :user_id, user_id) do
    from codes in query,
      where: codes.user_id == ^user_id
  end

  def _search(query, :purpose, purpose) do
    from codes in query,
      where: codes.purpose == ^purpose
  end

  def _search(query, :expired, false) do
    from codes in query,
      where: codes.expires > ^Timex.now()
  end

  def _search(query, :expired, true) do
    from codes in query,
      where: codes.expires < ^Timex.now()
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from codes in query,
      order_by: [desc: codes.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from codes in query,
      order_by: [asc: codes.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_user(query), else: query
    query
  end

  @spec _preload_user(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_user(query) do
    from codes in query,
      left_join: users in assoc(codes, :user),
      preload: [user: users]
  end
end
