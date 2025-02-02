defmodule TeiserverWeb.API.Admin.AssetController do
  use TeiserverWeb, :controller
  alias Teiserver.Asset

  plug Teiserver.OAuth.Plug.EnsureAuthenticated, scopes: ["admin.map"]

  def update_maps(conn, params) do
    attrs = Map.get(params, "maps", []) |> Enum.map(&update_map_to_attr/1)
    result = Asset.update_maps(attrs)

    case result do
      {:ok, res} ->
        conn |> assign(:result, res) |> put_status(:created) |> render(:map_updated)

      {:error, :bad_request} ->
        conn |> assign(:reason, "bad request: invalid input") |> render(:error)

      {:error, {op_name, err_changeset}} ->
        conn
        |> assign(:op_name, op_name)
        |> assign(:changeset, err_changeset)
        |> put_status(:bad_request)
        |> render(:map_updated_error)
    end
  end

  # bit cursed, not sure if there's a better way
  defp update_map_to_attr(attr) do
    for {k, v} <- attr do
      k =
        case k do
          "springName" -> "spring_name"
          "displayName" -> "display_name"
          "thumbnail" -> "thumbnail_url"
          "startboxesSet" -> "startboxes_set"
          "matchmakingQueues" -> "matchmaking_queues"
          "modoptions" -> "modoptions"
          k -> k
        end

      {k, v}
    end
    |> Map.new()
  end
end
