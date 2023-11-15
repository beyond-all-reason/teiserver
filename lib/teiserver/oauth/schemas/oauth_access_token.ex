defmodule Teiserver.OauthAccessTokens.OauthAccessToken do
  @moduledoc false
  use Ecto.Schema
  use ExOauth2Provider.AccessTokens.AccessToken, otp_app: :teiserver

  schema "oauth_access_tokens" do
    access_token_fields()

    timestamps()
  end
end
