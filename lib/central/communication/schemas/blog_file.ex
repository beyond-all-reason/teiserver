defmodule Central.Communication.BlogFile do
  @moduledoc false
  use CentralWeb, :schema

  schema "communication_blog_files" do
    field :name, :string
    field :url, :string
    field :file_path, :string
    field :file_ext, :string
    field :file_size, :integer

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(blog_file, attrs) do
    blog_file
    |> cast(attrs, [:name, :url, :file_ext, :file_path, :file_size])
    |> validate_required([:name, :url])
  end

  def file_upload_changeset(blog_file, file_path, file_ext, file_size) do
    blog_file
    |> cast(%{file_path: file_path, file_ext: file_ext, file_size: file_size}, [
      :file_path,
      :file_ext,
      :file_size
    ])
    |> validate_required([:file_path, :file_ext, :file_size])
  end

  def authorize(_, conn, _), do: allow?(conn, "communication.blog")
end
