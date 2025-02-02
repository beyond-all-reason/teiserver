defmodule TeiserverWeb.API.Admin.AssetController do
  use TeiserverWeb, :controller
  alias Teiserver.Asset

  plug Teiserver.OAuth.Plug.EnsureAuthenticated, scopes: ["admin.map"]

  def update_maps(conn, params) do
    with :ok <- validate_input(params),
         inputs <- Map.get(params, "maps", []) |> Enum.map(&update_map_to_attr/1),
         {:ok, res} <- Asset.update_maps(inputs) do
      conn |> assign(:result, res) |> put_status(:created) |> render(:map_updated)
    else
      {:error, {op_name, err_changeset}} ->
        conn
        |> assign(:op_name, op_name)
        |> assign(:changeset, err_changeset)
        |> put_status(:bad_request)
        |> render(:map_updated_error)

      {:error, %JsonXema.ValidationError{} = err} ->
        reason = JsonXema.ValidationError.format_error(err.reason)
        conn |> put_status(:bad_request) |> assign(:reason, reason) |> render(:error)
    end
  end

  @spec validate_input(term()) :: :ok | {:error, map()}
  defp validate_input(input) do
    # the whole endpoint should rarely be used, so we don't care *at all* about
    # performance of recompiling the schema every time
    %{
      "type" => "object",
      "required" => ["maps"],
      "properties" => %{
        "maps" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "required" => [
              "springName",
              "displayName",
              "thumbnail",
              "startboxesSet",
              "matchmakingQueues",
              "modoptions"
            ],
            "properties" => %{
              "springName" => %{"type" => "string"},
              "displayName" => %{"type" => "string"},
              "thumbnail" => %{"type" => "string"},
              "startboxesSet" => %{"type" => "array"},
              "matchmakingQueues" => %{"type" => "array", "items" => %{"type" => "string"}},
              "modoptions" => %{"type" => "object"}
            }
          }
        }
      }
    }
    |> JsonXema.new()
    |> JsonXema.validate(input)
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
