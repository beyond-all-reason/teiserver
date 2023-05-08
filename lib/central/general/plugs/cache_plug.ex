defmodule Central.General.CachePlug do
  @moduledoc false
  import Plug.Conn
  alias Central.Config

  def init(_) do
  end

  def call(%{user_id: nil} = conn, _) do
    conn
    |> assign(:memberships, [])
    |> assign(:tz, Application.get_env(:central, Central.Config)[:defaults].tz)
  end

  def call(conn, _) do
    conn
    |> assign(:tz, Config.get_user_config_cache(conn, "general.Timezone"))
  end

  def live_call(socket) do
    socket
    |> Phoenix.LiveView.Utils.assign(
      :tz,
      Config.get_user_config_cache(socket.assigns.user_id, "general.Timezone")
    )
  end
end
