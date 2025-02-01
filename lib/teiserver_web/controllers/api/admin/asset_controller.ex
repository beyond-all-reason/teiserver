defmodule TeiserverWeb.API.Admin.AssetController do
  use TeiserverWeb, :controller

  plug Teiserver.OAuth.Plug.EnsureAuthenticated, scopes: ["admin.map"]

  def ping(conn, _opts) do
    conn |> put_status(:not_implemented) |> render(:error)
  end
end
