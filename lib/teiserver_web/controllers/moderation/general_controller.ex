defmodule TeiserverWeb.Moderation.GeneralController do
  @moduledoc false
  use CentralWeb, :controller

  plug :add_breadcrumb, name: 'Moderation', url: '/moderation'

  plug(AssignPlug,
    site_menu_active: "moderation",
    sub_menu_active: "moderation"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderation.Report,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end
end
