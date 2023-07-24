defmodule Central.General.CachePlug do
  @moduledoc false
  import Plug.Conn
  alias Teiserver.Config

  def init(_) do
  end

  def call(%{user_id: nil} = conn, _) do
    conn
    |> assign(:tz, Application.get_env(:central, Teiserver.Config)[:defaults].tz)
    |> call_defaults
  end

  def call(conn, _) do
    conn
    |> assign(:tz, Config.get_user_config_cache(conn, "general.Timezone"))
    |> call_defaults
  end

  defp call_defaults(socket) do
    socket
    |> assign(:site_menu_active, "")
  end

  def live_call(%{assigns: %{current_user: %{id: userid}}} = socket) do
    socket
    |> Phoenix.LiveView.Utils.assign(
      :tz,
      Config.get_user_config_cache(userid, "general.Timezone")
    )
    |> live_call_defaults
  end

  def live_call(socket) do
    socket
    |> Phoenix.LiveView.Utils.assign(:tz, Application.get_env(:central, Teiserver.Config)[:defaults].tz)
    |> live_call_defaults
  end

  defp live_call_defaults(socket) do
    socket
    |> Phoenix.LiveView.Utils.assign(:site_menu_active, "")
  end
end
