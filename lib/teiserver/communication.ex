defmodule Teiserver.Communication do
  import Ecto.Query, warn: false
  # alias Central.Repo
  alias Central.Communication

  def get_category_id(category_name) do
    ConCache.get_or_store(:teiserver_blog_categories, category_name, fn ->
      case Communication.get_category(nil, search: [name: category_name]) do
        nil -> nil
        category -> category.id
      end
    end)
  end

  def get_latest_post(nil), do: nil
  def get_latest_post(category_id) do
    ConCache.get_or_store(:teiserver_blog_posts, :latest, fn ->
      posts = Communication.list_posts(
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
end
