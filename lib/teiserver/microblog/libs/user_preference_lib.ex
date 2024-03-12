defmodule Barserver.Microblog.UserPreferenceLib do
  @moduledoc false
  use BarserverWeb, :library_newform
  alias Barserver.Microblog.{UserPreference, UserPreferenceQueries}

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-cog"

  @spec colours :: atom
  def colours, do: :primary2

  @spec tag_mode_list() :: [String.t()]
  def tag_mode_list() do
    [
      "Block",
      "Filter",
      "Filter and block"
    ]
  end

  @doc """
  Returns the list of user_preferences.

  ## Examples

      iex> list_user_preferences()
      [%UserPreference{}, ...]

  """
  @spec list_user_preferences(list) :: [UserPreference]
  def list_user_preferences(args \\ []) do
    args
    |> UserPreferenceQueries.query_user_preferences()
    |> Repo.all()
  end

  @doc """
  Gets a single user_preference.

  Raises `Ecto.NoResultsError` if the UserPreference does not exist.

  ## Examples

      iex> get_user_preference!(123)
      %UserPreference{}

      iex> get_user_preference!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_user_preference!(non_neg_integer()) :: UserPreference.t()
  def get_user_preference!(user_preference_id) do
    [user_id: user_preference_id]
    |> UserPreferenceQueries.query_user_preferences()
    |> Repo.one!()
  end

  @spec get_user_preference!(non_neg_integer(), list) :: UserPreference.t()
  def get_user_preference!(user_preference_id, args) do
    ([user_id: user_preference_id] ++ args)
    |> UserPreferenceQueries.query_user_preferences()
    |> Repo.one!()
  end

  @spec get_user_preference(non_neg_integer()) :: UserPreference.t() | nil
  def get_user_preference(user_preference_id) do
    [user_id: user_preference_id]
    |> UserPreferenceQueries.query_user_preferences()
    |> Repo.one()
  end

  @spec get_user_preference(non_neg_integer(), list) :: UserPreference.t() | nil
  def get_user_preference(user_preference_id, args) do
    ([user_id: user_preference_id] ++ args)
    |> UserPreferenceQueries.query_user_preferences()
    |> Repo.one()
  end

  @doc """
  Creates a user_preference.

  ## Examples

      iex> create_user_preference(%{field: value})
      {:ok, %UserPreference{}}

      iex> create_user_preference(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_preference(attrs \\ %{}) do
    %UserPreference{}
    |> UserPreference.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_preference.

  ## Examples

      iex> update_user_preference(user_preference, %{field: new_value})
      {:ok, %UserPreference{}}

      iex> update_user_preference(user_preference, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_preference(%UserPreference{} = user_preference, attrs) do
    user_preference
    |> UserPreference.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user_preference.

  ## Examples

      iex> delete_user_preference(user_preference)
      {:ok, %UserPreference{}}

      iex> delete_user_preference(user_preference)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_preference(%UserPreference{} = user_preference) do
    Repo.delete(user_preference)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_preference changes.

  ## Examples

      iex> change_user_preference(user_preference)
      %Ecto.Changeset{data: %UserPreference{}}

  """
  def change_user_preference(%UserPreference{} = user_preference, attrs \\ %{}) do
    UserPreference.changeset(user_preference, attrs)
  end
end
