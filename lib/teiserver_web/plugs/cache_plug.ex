defmodule Teiserver.Plugs.CachePlug do
  @moduledoc false
  import Plug.Conn
  alias Teiserver.Config

  def init(_) do
  end

  def call(%{assigns: %{user_id: nil}} = conn, _) do
    conn
    |> assign(:tz, Application.get_env(:teiserver, Teiserver.Config)[:defaults].tz)
  end

  def call(conn, _) do
    conn
    |> assign(:tz, Config.get_user_config_cache(conn, "general.Timezone"))
  end

  def live_call(%{assigns: %{current_user: %{id: userid}}} = socket) do
    socket
    |> Phoenix.LiveView.Utils.assign(
      :tz,
      Config.get_user_config_cache(userid, "general.Timezone")
    )
  end

  def live_call(socket) do
    socket
    |> Phoenix.LiveView.Utils.assign(
      :tz,
      Application.get_env(:teiserver, Teiserver.Config)[:defaults].tz
    )
  end
end
