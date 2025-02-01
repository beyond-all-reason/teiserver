defmodule TeiserverWeb.API.Admin.AssetController do
  use TeiserverWeb, :controller

  def ping(conn, _opts) do
    conn |> put_status(:not_implemented) |> render(:error)
  end
end
