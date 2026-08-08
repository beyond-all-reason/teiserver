defmodule Teiserver.Account.AuthPipeline do
  @moduledoc """
  Guardian pipeline for the browser. The token lives in the session, so this
  only ever looks at the session. Bearer tokens are the api's business, see
  `Teiserver.Account.ApiAuthPlug`.
  """
  use Guardian.Plug.Pipeline,
    otp_app: :teiserver,
    error_handler: Teiserver.Account.ErrorHandler,
    module: Teiserver.Account.Guardian

  # If there is a session token, restrict it to an access token and validate it
  plug Guardian.Plug.VerifySession, claims: %{"typ" => "access"}
  # Load the user if the verification worked
  plug Guardian.Plug.LoadResource, allow_blank: true
end
