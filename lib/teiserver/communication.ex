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
  Gets a single text_callback.

  Raises `Ecto.NoResultsError` if the TextCallback does not exist.

  ## Examples

      iex> get_text_callback!(123)
      %TextCallback{}

      iex> get_text_callback!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_text_callback!(Integer.t() | List.t()) :: TextCallback.t()
  @spec get_text_callback!(Integer.t(), List.t()) :: TextCallback.t()
  def get_text_callback!(id) when not is_list(id) do
    lobby_text_callback(id, [])
    |> Repo.one!()
  end

  def get_text_callback!(args) do
    lobby_text_callback(nil, args)
    |> Repo.one!()
  end

  def get_text_callback!(id, args) do
    lobby_text_callback(id, args)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single text_callback.

  # Returns `nil` if the TextCallback does not exist.

  # ## Examples

  #     iex> get_text_callback(123)
  #     %TextCallback{}

  #     iex> get_text_callback(456)
  #     nil

  # """
  # def get_text_callback(id, args \\ []) when not is_list(id) do
  #   lobby_text_callback(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a text_callback.

  ## Examples

      iex> create_text_callback(%{field: value})
      {:ok, %TextCallback{}}

      iex> create_text_callback(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_text_callback(Map.t()) :: {:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}
  def create_text_callback(attrs \\ %{}) do
    %TextCallback{}
    |> TextCallback.changeset(attrs)
    |> Repo.insert()
    |> update_text_callback_cache()
  end

  @doc """
  Updates a text_callback.

  ## Examples

      iex> update_text_callback(text_callback, %{field: new_value})
      {:ok, %TextCallback{}}

      iex> update_text_callback(text_callback, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_text_callback(TextCallback.t(), Map.t()) ::
          {:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}
  def update_text_callback(%TextCallback{} = text_callback, attrs) do
    text_callback
    |> TextCallback.changeset(attrs)
    |> Repo.update()
    |> update_text_callback_cache()
  end

  @doc """
  Deletes a TextCallback.

  ## Examples

      iex> delete_text_callback(text_callback)
      {:ok, %TextCallback{}}

      iex> delete_text_callback(text_callback)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_text_callback(TextCallback.t()) ::
          {:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}
  def delete_text_callback(%TextCallback{} = text_callback) do
    Repo.delete(text_callback)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking text_callback changes.

  ## Examples

      iex> change_text_callback(text_callback)
      %Ecto.Changeset{source: %TextCallback{}}

  """
  @spec change_text_callback(TextCallback.t()) :: Ecto.Changeset.t()
  def change_text_callback(%TextCallback{} = text_callback) do
    TextCallback.changeset(text_callback, %{})
  end

  @spec build_text_callback_cache() :: :ok
  defdelegate build_text_callback_cache, to: TextCallbackLib

  @spec update_text_callback_cache({:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}) :: {:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}
  defdelegate update_text_callback_cache(args), to: TextCallbackLib

  @spec lookup_text_callback_from_trigger(String.t()) :: TextCallback.t() | nil
  defdelegate lookup_text_callback_from_trigger(trigger), to: TextCallbackLib
end
