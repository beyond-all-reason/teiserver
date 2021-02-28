defmodule Central.General.CachePlug do
  @moduledoc false
  import Plug.Conn
  alias Central.Account

  def init(_) do
  end

  def call(%{user_id: nil} = conn, _) do
    conn
  end

  def call(conn, _) do
    conn
    |> assign(:memberships, Account.list_group_memberships_cache(conn.user_id))
  end
end
