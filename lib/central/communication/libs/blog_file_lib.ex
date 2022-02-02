defmodule Central.Communication.BlogFileLib do
  @moduledoc false
  use CentralWeb, :library

  alias Central.Communication.BlogFile

  def colours(), do: Central.Helpers.StylingHelper.colours(:warning2)
  def icon(), do: "far fa-file"

  # Queries
  @spec get_blog_files() :: Ecto.Query.t()
  def get_blog_files do
    from(blog_files in BlogFile)
  end

  @spec search(Ecto.Query.t(), map | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from blog_files in query,
      where: blog_files.id == ^id
  end

  def _search(query, :name, name) do
    from blog_files in query,
      where: blog_files.name == ^name
  end

  def _search(query, :url, url) do
    from blog_files in query,
      where: blog_files.url == ^url
  end

  # def _search(query, :membership, %{assigns: %{memberships: group_ids}}) do
  #   _search(query, :membership, group_ids)
  # end

  # def _search(query, :membership, group_ids) do
  #   from blog_files in query,
  #     where: blog_files.group_id in ^group_ids
  # end

  def _search(query, :id_list, id_list) do
    from blog_files in query,
      where: blog_files.id in ^id_list
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from blog_files in query,
      where: ilike(blog_files.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from blog_files in query,
      order_by: [asc: blog_files.name]
  end

  def order_by(query, "Name (Z-A)") do
    from blog_files in query,
      order_by: [desc: blog_files.name]
  end

  def order_by(query, "Newest first") do
    from blog_files in query,
      order_by: [desc: blog_files.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from blog_files in query,
      order_by: [asc: blog_files.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  def build_filename(the_file, filename) do
    "i#{the_file.id}_#{filename}"
    |> String.replace("'", "")
  end

  def store_file(the_file, upload_path, filename) do
    the_file_save_path =
      Application.get_env(:central, Central.Communication.BlogFile)
      |> Keyword.get(:save_path)

    # Stat the upload
    {upload_stat, _} = System.cmd("stat", ["--printf=\"%s\"", upload_path])

    upload_path = upload_path
    filename = build_filename(the_file, filename)
    new_path = "#{the_file_save_path}/#{filename}"

    # Now move it
    System.cmd("mv", [upload_path, new_path])

    # Stat the moved file
    {moved_stat, _} = System.cmd("stat", ["--printf=\"%s\"", new_path])

    if moved_stat == upload_stat do
      {:ok, new_path, moved_stat |> to_string}
    else
      the_file
      |> Repo.delete()

      {:error, "There was an error uploading the file."}
    end
  end

  def delete_file(%{file_path: nil}), do: true

  def delete_file(file) do
    base_path =
      Application.get_env(:central, Central.Communication.BlogFile)
      |> Keyword.get(:save_path)

    file_name = String.replace(file.file_path, base_path, "")
    actual_path = "#{base_path}#{file_name}"

    moved_stat =
      System.cmd("stat", ["--printf=\"%s\"", actual_path])
      |> elem(0)
      |> String.slice(0..17)

    if moved_stat != "stat: cannot stat " do
      # Do delete
      System.cmd("rm", [actual_path])

      # Re-call this function
      delete_file(file)
    else
      true
    end
  end
end
