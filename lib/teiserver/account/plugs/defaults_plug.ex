defmodule Teiserver.Account.DefaultsPlug do
  @moduledoc false
  alias Phoenix.Component

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

  def on_mount({:set, params}, _url_params, _session, socket) do
    {:cont, Component.assign(socket, params)}
  end
end
