defmodule Central.Account.DefaultsPlug do
  @moduledoc false
  import Plug.Conn

  def init(_opts) do
    # Keyword.fetch!(opts, :repo)
  end

  def call(conn, _opts) do
    conn
    |> assign(:site_menu_active, "")
    |> assign(:sub_menu_active, "")
    |> assign(:section_menu_active, "")
  end

  def live_call(socket, _session) do
    socket
    |> Phoenix.LiveView.assign(:site_menu_active, [])
    |> Phoenix.LiveView.assign(:sub_menu_active, [])
    |> Phoenix.LiveView.assign(:section_menu_active, [])
  end
end
