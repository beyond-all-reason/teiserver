defmodule Teiserver.OAuth.TokenPlug do
  @behaviour Plug

  import Plug.Conn

  def init(opts), do: opts

  # Pretty sure there's a better way to return the response than hardcode
  # a json response and manually encode, but for now it'll be enough
  def call(conn, _opts) do
    with ["Bearer " <> raw_token] <- get_req_header(conn, "authorization"),
         {:ok, token} <- Teiserver.OAuth.get_valid_token(raw_token) do
      # TODO: validate scope once we have more than one (v0.tachyon only for now)
      if token.type == :access do
        assign(conn, :token, token)
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
      err ->
        conn
        |> put_resp_header("www-authenticate", "Unauthorized")
        |> put_resp_header("content-type", "application/json")
        |> resp(
          401,
          Jason.encode!(%{error: "unauthorized_client", error_description: inspect(err)})
        )
        |> halt()
    end
  end
end
