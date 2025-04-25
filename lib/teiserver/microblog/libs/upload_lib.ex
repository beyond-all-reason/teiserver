defmodule Teiserver.Microblog.UploadLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Microblog.{Upload, UploadQueries}

  @doc """
  Returns the list of uploads.
  ## Examples
      iex> list_uploads()
      [%Upload{}, ...]
  """
  @spec list_uploads(list) :: [Upload.t()]
  def list_uploads(args \\ []) do
    args
    |> UploadQueries.query_uploads()
    |> Repo.all()
  end

  @doc """
  Gets a single upload.
  Raises `Ecto.NoResultsError` if the Upload does not exist.
  ## Examples
      iex> get_upload!(123)
      %Upload{}
      iex> get_upload!(456)
      ** (Ecto.NoResultsError)
  """
  @spec get_upload!(Ecto.UUID.t()) :: Upload.t()
  def get_upload!(upload_id) do
    [id: upload_id]
    |> UploadQueries.query_uploads()
    |> Repo.one!()
  end

  @spec get_upload!(Ecto.UUID.t(), list) :: Upload.t()
  def get_upload!(upload_id, args) do
    ([id: upload_id] ++ args)
    |> UploadQueries.query_uploads()
    |> Repo.one!()
  end

  @spec get_upload(Ecto.UUID.t()) :: Upload.t() | nil
  def get_upload(upload_id) do
    [id: upload_id]
    |> UploadQueries.query_uploads()
    |> Repo.one()
  end

  @spec get_upload(Ecto.UUID.t(), list) :: Upload.t() | nil
  def get_upload(upload_id, args) do
    ([id: upload_id] ++ args)
    |> UploadQueries.query_uploads()
    |> Repo.one()
  end

  @doc """
  Creates a upload.
  ## Examples
      iex> create_upload(%{field: value})
      {:ok, %Upload{}}
      iex> create_upload(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_upload(attrs \\ %{}) do
    %Upload{}
    |> Upload.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a upload.
  ## Examples
      iex> update_upload(upload, %{field: new_value})
      {:ok, %Upload{}}
      iex> update_upload(upload, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_upload(%Upload{} = upload, attrs) do
    upload
    |> Upload.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a upload.
  ## Examples
      iex> delete_upload(upload)
      {:ok, %Upload{}}
      iex> delete_upload(upload)
      {:error, %Ecto.Changeset{}}
  """
  def delete_upload(%Upload{} = upload) do
    File.rm(upload.filename)
    Repo.delete(upload)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking upload changes.
  ## Examples
      iex> change_upload(upload)
      %Ecto.Changeset{data: %Upload{}}
  """
  def change_upload(%Upload{} = upload, attrs \\ %{}) do
    Upload.changeset(upload, attrs)
  end
end
