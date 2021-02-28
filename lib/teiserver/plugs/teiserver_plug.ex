defmodule Teiserver.ServerUserPlug do
  import Plug.Conn
  alias Teiserver.User

  def init(_opts) do
    # Keyword.fetch!(opts, :repo)
  end

  def call(%{assigns: %{current_user: nil}} = conn, _opts) do
    conn
    |> assign(:server_user, nil)
  end

  def call(%{assigns: %{current_user: current_user}} = conn, _opts) do
    userid = current_user.id
    server_user = User.get_user_by_id(userid)

    conn
    |> assign(:server_user, server_user)
  end
  def call(conn, _opts) do
    conn
    |> assign(:server_user, nil)
  end

  def live_call(%{assigns: %{current_user: current_user}} = socket, session) do
    userid = current_user.id
    server_user = User.get_user_by_id(userid)

    socket
    |> Phoenix.LiveView.assign(:server_user, server_user)
  end
end