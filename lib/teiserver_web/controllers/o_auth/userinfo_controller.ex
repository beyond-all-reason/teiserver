defmodule TeiserverWeb.OAuth.UserinfoController do
  alias Teiserver.Account.Auth

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

    claims = %{sub: sub, id: sub}
    info_scopes = ["profile", "email", "groups"]

    claims =
      Enum.reduce(info_scopes, claims, fn scope, claims ->
        if scope in token.scopes,
          do: add_claims(claims, token, scope),
          else: claims
      end)

    render(conn, :userinfo, claims: claims)
  end

  defp add_claims(claims, token, "profile") do
    case get_in(token.owner.name) do
      nil -> claims
      name -> Map.put(claims, :preferred_username, name)
    end
  end

  defp add_claims(claims, %{owner: owner}, "email") when owner != nil do
    claims
    |> Map.put(:email, owner.email)
    |> Map.put(:email_verified, Auth.verified?(owner))
  end

  defp add_claims(claims, _token, "email"), do: claims

  defp add_claims(claims, token, "groups") do
    groups = get_in(token.owner.roles) || []

    claims
    |> Map.put(:groups, Enum.map(groups, &String.downcase/1))
  end
end
