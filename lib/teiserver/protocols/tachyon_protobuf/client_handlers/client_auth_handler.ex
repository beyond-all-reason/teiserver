defmodule Teiserver.Tachyon.ClientAuthHandler do
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.TachyonPbLib

  @spec handle_token_request(Tachyon.TokenRequest.t(), T.tachyon_tcp_state()) :: Tachyon.TokenResponse.t()
  def handle_token_request(%{email: email, password: password}, _state) do
    if password == "password" do
      Tachyon.TokenResponse.new(
        token: "token"
      )
    else
      Tachyon.Failure.new(
        action: "token_request",
        reason: "Bad auth"
      )
    end
  end
end
