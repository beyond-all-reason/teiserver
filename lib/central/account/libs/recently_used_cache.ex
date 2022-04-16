defmodule Central.Account.RecentlyUsedCache do
  @moduledoc false
  alias Central.Types, as: T

  @recently_used_limit 50

  @spec insert_recently(map()) :: map()
  def insert_recently(item) do
    user_id = item.user_id

    existing = get_recently(item.user_id)

    new_items = existing
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
end
