defmodule Central.Account.DefaultsPlug do
  @moduledoc false
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    conn
    |> assign(:site_menu_active, "")
    |> assign(:sub_menu_active, "")
    |> assign(:section_menu_active, "")
  end
end
