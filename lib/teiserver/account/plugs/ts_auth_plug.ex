defmodule Teiserver.Account.TSAuthPlug do
  @moduledoc false
  import Plug.Conn
  alias Teiserver.User

  def init(_opts) do
    # Keyword.fetch!(opts, :repo)
  end

  def call(%{assigns: %{current_user: nil}} = conn, _opts), do: conn

  def call(%{assigns: %{current_user: current_user}} = conn, _opts) do
    if User.is_restricted?(current_user.id, ["Site"]) do
      conn
      |> assign(:current_user, nil)
    else
      conn
    end
  end

  def live_call(%{assigns: %{current_user: nil}} = socket, _session), do: socket

  def live_call(%{assigns: %{current_user: current_user}} = socket, _session) do
    if User.is_restricted?(current_user.id, ["Site"]) do
      socket
      |> Phoenix.LiveView.Utils.assign(:current_user, nil)
    else
      socket
    end
  end
end
