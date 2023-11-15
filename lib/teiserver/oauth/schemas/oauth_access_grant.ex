defmodule Teiserver.OauthAccessGrants.OauthAccessGrant do
  @moduledoc false
  use Ecto.Schema
  use ExOauth2Provider.AccessGrants.AccessGrant, otp_app: :teiserver

  schema "oauth_access_grants" do
    access_grant_fields()

    timestamps()
  end
end
