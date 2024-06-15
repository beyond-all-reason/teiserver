defmodule TeiserverWeb.OAuth.CodeController do
  use TeiserverWeb, :controller
  alias Teiserver.OAuth

  # https://www.rfc-editor.org/rfc/rfc6749.html#section-4.1.3
  @spec exchange_code(Conn.t(), %{}) :: Conn.t()

  def exchange_code(conn, %{"grant_type" => grant_type})
      when grant_type != "authorization_code" do
    conn
    |> put_status(400)
    |> render(:error, error_description: "grant_type must be authorization_code")
  end

  def exchange_code(conn, params) do
    case Enum.find(
           ["client_id", "code", "redirect_uri", "client_id", "code_verifier", "grant_type"],
           fn key -> not Map.has_key?(params, key) end
         ) do
      nil ->
        do_exchange_token(conn, params)

      missing_key ->
        conn |> put_status(400) |> render(:error, error_description: "missing #{missing_key}")
    end
  end

  defp do_exchange_token(conn, params) do
    with app when app != nil <- OAuth.get_application_by_uid(params["client_id"]),
         {:ok, code} <- OAuth.get_valid_code(params["code"]),
         true <- code.application_id == app.id,
         {:ok, token} <-
           OAuth.exchange_code(code, params["code_verifier"], params["redirect_uri"]) do
      conn |> put_status(200) |> render(:token, token: token)
    else
      _ -> conn |> put_status(400) |> render(:error, error_description: "invalid request")
    end
  end
end
