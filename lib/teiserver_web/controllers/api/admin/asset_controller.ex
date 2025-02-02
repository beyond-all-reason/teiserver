defmodule TeiserverWeb.API.Admin.AssetController do
  use TeiserverWeb, :controller
  alias Teiserver.Asset

  plug Teiserver.OAuth.Plug.EnsureAuthenticated, scopes: ["admin.map"]

  def update_maps(conn, params) do
    result =
      Asset.update_maps(params["maps"])

    case result do
      {:ok, res} ->
        conn |> assign(:result, res) |> put_status(:created) |> render(:map_updated)

      {:error, {op_name, err_changeset}} ->
        conn
        |> assign(:op_name, op_name)
        |> assign(:changeset, err_changeset)
        |> put_status(:bad_request)
        |> render(:map_updated_error)
    end
  end
end
