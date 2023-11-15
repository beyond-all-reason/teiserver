defmodule Teiserver.OauthApplications.OauthApplication do
  @moduledoc false
  use Ecto.Schema
  use ExOauth2Provider.Applications.Application, otp_app: :teiserver

  schema "oauth_applications" do
    application_fields()

    timestamps()
  end
end
