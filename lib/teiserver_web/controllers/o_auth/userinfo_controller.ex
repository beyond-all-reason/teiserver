defmodule TeiserverWeb.OAuth.UserinfoController do
  use TeiserverWeb, :controller

  # we don't check for scopes at that point, just that there is a valid token
  plug TeiserverWeb.Plugs.OAuthAuthenticatedPlug, scopes: []

  def get(conn, _params) do
    token = conn.assigns[:token]

    sub =
      cond do
        token.owner != nil -> to_string(token.owner.id)
        token.bot != nil -> to_string(token.bot.id)
        true -> raise "token has no owner nor bot!"
      end

    claims = %{
      sub: sub
    }

    render(conn, :userinfo, claims: claims)
  end
end
