defmodule Teiserver.Communication do
  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo
  alias Central.Communication

  def get_category_id(category_name) do
    Central.cache_get_or_store(:teiserver_blog_categories, category_name, fn ->
      case Communication.get_category(nil, search: [name: category_name]) do
        nil -> nil
        category -> category.id
      end
    end)
  end

  def get_latest_post(nil), do: nil

  def get_latest_post(category_id) do
    Central.cache_get_or_store(:teiserver_blog_posts, :latest, fn ->
      posts =
        Communication.list_posts(
          search: [category_id: category_id],
          joins: [],
          order_by: "Newest first",
          limit: 1
        )

      case posts do
        [] -> nil
        [post] -> post
      end
    end)
  end

  alias Teiserver.Communication.{TextCallback, TextCallbackLib}

  @spec lobby_text_callback(List.t()) :: Ecto.Query.t()
  def lobby_text_callback(args) do
    lobby_text_callback(nil, args)
  end

  @spec lobby_text_callback(Integer.t(), List.t()) :: Ecto.Query.t()
  def lobby_text_callback(id, args) do
    TextCallbackLib.query_text_callbacks()
    |> TextCallbackLib.search(%{id: id})
    |> TextCallbackLib.search(args[:search])
    |> TextCallbackLib.preload(args[:preload])
    |> TextCallbackLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of text_callbacks.

  ## Examples

      iex> list_text_callbacks()
      [%TextCallback{}, ...]

  """
  @spec list_text_callbacks(List.t()) :: List.t()
  def list_text_callbacks(args \\ []) do
    lobby_text_callback(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single lobby_policy.

  Raises `Ecto.NoResultsError` if the TextCallback does not exist.

  ## Examples

      iex> get_lobby_policy!(123)
      %TextCallback{}

      iex> get_lobby_policy!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_lobby_policy!(Integer.t() | List.t()) :: TextCallback.t()
  @spec get_lobby_policy!(Integer.t(), List.t()) :: TextCallback.t()
  def get_lobby_policy!(id) when not is_list(id) do
    lobby_text_callback(id, [])
    |> Repo.one!()
  end

  def get_lobby_policy!(args) do
    lobby_text_callback(nil, args)
    |> Repo.one!()
  end

  def get_lobby_policy!(id, args) do
    lobby_text_callback(id, args)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single lobby_policy.

  # Returns `nil` if the TextCallback does not exist.

  # ## Examples

  #     iex> get_lobby_policy(123)
  #     %TextCallback{}

  #     iex> get_lobby_policy(456)
  #     nil

  # """
  # def get_lobby_policy(id, args \\ []) when not is_list(id) do
  #   lobby_text_callback(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a lobby_policy.

  ## Examples

      iex> create_lobby_policy(%{field: value})
      {:ok, %TextCallback{}}

      iex> create_lobby_policy(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_lobby_policy(Map.t()) :: {:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}
  def create_lobby_policy(attrs \\ %{}) do
    %TextCallback{}
    |> TextCallback.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a lobby_policy.

  ## Examples

      iex> update_lobby_policy(lobby_policy, %{field: new_value})
      {:ok, %TextCallback{}}

      iex> update_lobby_policy(lobby_policy, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_lobby_policy(TextCallback.t(), Map.t()) ::
          {:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}
  def update_lobby_policy(%TextCallback{} = lobby_policy, attrs) do
    lobby_policy
    |> TextCallback.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a TextCallback.

  ## Examples

      iex> delete_lobby_policy(lobby_policy)
      {:ok, %TextCallback{}}

      iex> delete_lobby_policy(lobby_policy)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_lobby_policy(TextCallback.t()) ::
          {:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}
  def delete_lobby_policy(%TextCallback{} = lobby_policy) do
    Repo.delete(lobby_policy)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lobby_policy changes.

  ## Examples

      iex> change_lobby_policy(lobby_policy)
      %Ecto.Changeset{source: %TextCallback{}}

  """
  @spec change_lobby_policy(TextCallback.t()) :: Ecto.Changeset.t()
  def change_lobby_policy(%TextCallback{} = lobby_policy) do
    TextCallback.changeset(lobby_policy, %{})
  end
end
