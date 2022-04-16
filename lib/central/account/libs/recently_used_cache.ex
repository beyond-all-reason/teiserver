defmodule Central.Account.RecentlyUsedCache do
  @moduledoc false
  alias Central.Types, as: T

  @recently_used_limit 50

  @spec insert_recently(map()) :: map()
  def insert_recently(%{user_id: user_id} = item) do
    new_items = user_id
      |> get_recently
      |> Enum.filter(fn r ->
        r.item_id != item.item_id or r.item_type != item.item_type
      end)
      |> Enum.take(@recently_used_limit)

    Central.cache_put(:recently_used_cache, user_id, [item | new_items])

    item
  end

  @spec insert_recently(map(), Plug.Conn.t()) :: map()
  def insert_recently(item, conn) do
    item
      |> Map.merge(%{
        user_id: conn.assigns[:current_user].id
      })
      |> insert_recently
  end

  @spec get_recently(Plug.Conn.t() | T.user_id()) :: [map()]
  def get_recently(%{assigns: %{current_user: current_user}}) do
    get_recently(current_user.id)
  end

  def get_recently(user_id) do
    Central.cache_get(:recently_used_cache, user_id) || []
  end


  @spec remove_recently(map()) :: :ok
  def remove_recently(%{user_id: user_id} = item) do
    new_items = user_id
      |> get_recently()
      |> Enum.filter(fn r ->
        r.item_id != item.item_id or r.item_type != item.item_type
      end)

    Central.cache_put(:recently_used_cache, user_id, new_items)

    :ok
  end

  @spec remove_recently(map(), Plug.Conn.t()) :: :ok
  def remove_recently(item, conn) do
    item
      |> Map.merge(%{
        user_id: conn.assigns[:current_user].id
      })
      |> remove_recently
  end
end
