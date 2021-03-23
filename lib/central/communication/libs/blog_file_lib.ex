defmodule Central.Communication.BlogFileLib do
  use CentralWeb, :library

  alias Central.Communication.BlogFile

  def colours(), do: {"#CC4400", "#FFDDCC", "warning2"}
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

  # def _preload_things(query) do
  #   from blog_files in query,
  #     left_join: things in assoc(blog_files, :things),
  #     preload: [things: things]
  # end

  # @spec get_blog_file(integer) :: Ecto.Query.t
  # def get_blog_file(blog_file_id) do
  #   from blog_files in BlogFile,
  #     where: blog_files.id == ^blog_file_id
  # end

  # @spec get_blog_file_from_slug(String.t()) :: BlogFile.t
  # def get_blog_file_from_slug(slug) do
  #   query = from blog_files in BlogFile,
  #     where: blog_files.url == ^slug

  #   Repo.one(query)
  # end

  # @spec get_blog_files() :: Ecto.Query.t
  # def get_blog_files() do
  #   from blog_files in BlogFile
  # end

  # @spec search(Ecto.Query.t, atom, nil) :: Ecto.Query.t
  # @spec search(Ecto.Query.t, atom, String.t()) :: Ecto.Query.t
  # def search(query, _, nil), do: query
  # def search(query, _, ""), do: query

  # def search(query, :simple_search, value) do
  #   value_like = "%" <> String.replace(value, "*", "%") <> "%"

  #   # TODO from blueprints
  #   # Put in the simple-search strings here

  #   from blog_files in query,
  #     where: (
  #            ilike(blog_files.str1, ^value_like)
  #         or ilike(blog_files.str2, ^value_like)
  #       )
  # end

  # # def search(query, :groups, groups) do
  # #   from blog_files in query,
  # #     where: blog_files.group_id in ^groups
  # # end

  # def search(query, :name, name) do
  #   name = "%" <> String.replace(name, "*", "%") <> "%"

  #   from blog_files in query,
  #     where: ilike(blog_files.name, ^name)
  # end

  # def search(query, :url, url) do
  #   url = "%" <> String.replace(url, "*", "%") <> "%"

  #   from blog_files in query,
  #     where: ilike(blog_files.url, ^url)
  # end

  # def search(query, :file_path, file_path) do
  #   file_path = "%" <> String.replace(file_path, "*", "%") <> "%"

  #   from blog_files in query,
  #     where: ilike(blog_files.file_path, ^file_path)
  # end

  # def search(query, :file_ext, file_ext) do
  #   file_ext = "%" <> String.replace(file_ext, "*", "%") <> "%"

  #   from blog_files in query,
  #     where: ilike(blog_files.file_ext, ^file_ext)
  # end

  # def search(query, :file_size, file_size) do
  #   from blog_files in query,
  #     where: blog_files.file_size == ^file_size
  # end

  # def search(query, :file_type, file_type) do
  #   file_type = "%" <> String.replace(file_type, "*", "%") <> "%"

  #   from blog_files in query,
  #     where: ilike(blog_files.file_type, ^file_type)
  # end

  # def search(query, :ids, ids) do
  #   from blog_files in query,
  #     where: blog_files.id in ^ids
  # end

  # def search(query, :inserted_at_start, inserted_at_start) do
  #   inserted_at_start = Timex.parse!(inserted_at_start, "{0D}/{0M}/{YYYY}")

  #   from blog_files in query,
  #     where: blog_files.inserted_at > ^inserted_at_start
  # end

  # def search(query, :inserted_at_end, inserted_at_end) do
  #   inserted_at_end = Timex.parse!(inserted_at_end, "{0D}/{0M}/{YYYY}")

  #   from blog_files in query,
  #     where: blog_files.inserted_at < ^inserted_at_end
  # end

  # @spec order(Ecto.Query.t, String.t()) :: Ecto.Query.t
  # def order(query, "Newest first") do
  #   from blog_files in query,
  #     order_by: [desc: blog_files.inserted_at]
  # end

  # def order(query, "Oldest first") do
  #   from blog_files in query,
  #     order_by: [asc: blog_files.inserted_at]
  # end

  def build_filename(the_file, filename) do
    "i#{the_file.id}_#{filename}"
    |> String.replace("'", "")
  end

  def store_file(the_file, upload_path, filename) do
    the_file_save_path =
      Application.get_env(:central, Central.Communication.BlogFile)
      |> Keyword.get(:save_path)

    # Stat the upload
    upload_stat = :os.cmd('stat --printf="%s" #{upload_path}')

    upload_path = upload_path
    filename = build_filename(the_file, filename)
    new_path = "#{the_file_save_path}/#{filename}"

    # Now move it
    :os.cmd('mv "#{upload_path}" "#{new_path}";')

    # Stat the moved file
    moved_stat = :os.cmd('stat --printf="%s" "#{new_path}"')

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
      'stat --printf="%s" "#{actual_path}"'
      |> :os.cmd()
      |> to_string
      |> String.slice(0..17)

    if moved_stat != "stat: cannot stat " do
      # Do delete
      :os.cmd('rm "#{actual_path}"')

      # Re-call this function
      delete_file(file)
    else
      true
    end
  end
end
