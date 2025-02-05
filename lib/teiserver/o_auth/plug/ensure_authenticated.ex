defmodule Teiserver.OAuth.Plug.EnsureAuthenticated do
  @behaviour Plug

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) when is_map_key(conn.assigns, :token) do
    token = conn.assigns[:token]

    case has_all_scopes?(token, opts[:scopes]) do
      :ok -> conn
      err -> unauthorized(conn, err)
    end
  end

  def call(conn, opts) do
    with {:ok, raw_token} <- get_token(conn),
         {:ok, token} <- Teiserver.OAuth.get_valid_token(raw_token) do
      if token.type == :access do
        assign(conn, :token, token) |> call(opts)
      else
        conn
        |> put_resp_header("content-type", "application/json")
        |> resp(
          :bad_request,
          Jason.encode!(%{
            error: "invalid_request",
            error_description: "Cannot use refresh token to connect"
          })
        )
        |> halt()
      end
    else
      err -> unauthorized(conn, err)
    end
  end

  # Pretty sure there's a better way to return the response than hardcode
  # a json response and manually encode, but for now it'll be enough
  defp unauthorized(conn, err) do
    conn
    |> put_resp_header("www-authenticate", "Unauthorized")
    |> put_resp_header("content-type", "application/json")
    |> resp(
      401,
      Jason.encode!(%{error: "unauthorized_client", error_description: inspect(err)})
    )
    |> halt()
  end

  defp get_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> raw_token] -> {:ok, raw_token}
      _ -> {:error, "invalid bearer token"}
    end
  end

  defp has_all_scopes?(_token, nil), do: :ok

  defp has_all_scopes?(token, requested_scopes) do
    diff = MapSet.difference(MapSet.new(requested_scopes), MapSet.new(token.scopes))

    if Enum.empty?(diff) do
      :ok
    else
      missing = Enum.join(diff, ", ")

      if Enum.count(diff) == 1 do
        "Access denied, missing the following scope: #{missing}"
      else
        "Access denied, missing the following scopes: #{missing}"
      end
    end
  end
end
