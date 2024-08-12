defmodule Teiserver.Test.Support.OAuth do
  alias Teiserver.OAuth

  @doc """
  utility to create an OAuth authorization code for the given user and application
  """
  @spec create_code(
          Teiserver.Account.User.t(),
          %{
            id: integer(),
            scopes: OAuth.Application.scopes(),
            redirect_uri: String.t(),
            challenge: String.t(),
            challenge_method: String.t()
          },
          OAuth.options()
        ) :: {:ok, OAuth.Code.t(), map()}
  def create_code(user, app, opts \\ []) do
    {verifier, challenge, method} = generate_challenge()

    redir_uri = Map.get(app, :redirect_uri, "http://some.host/a/path")

    attrs = %{
      id: app.id,
      scopes: app.scopes,
      redirect_uri: redir_uri,
      challenge: challenge,
      challenge_method: method
    }

    {:ok, code} = OAuth.create_code(user, attrs, opts)
    {:ok, code, Map.put(attrs, :verifier, verifier)}
  end

  defp generate_challenge() do
    # A-Z,a-z,0-9 and -._~ are authorized, but can't be bothered to cover all
    # of that. hex encoding will fit
    # hardcoded random bytes generated with :crypto.strong_rand_bytes(32)
    bytes =
      <<30, 33, 141, 180, 13, 27, 42, 190, 106, 230, 111, 140, 162, 230, 128, 110, 149, 65, 33,
        124, 129, 9, 89, 93, 94, 248, 46, 34, 116, 186, 8, 24>>

    verifier = Base.hex_encode32(bytes, padding: false)

    challenge = hash_verifier(verifier)

    {verifier, challenge, "S256"}
  end

  def hash_verifier(verifier),
    do: Base.url_encode64(:crypto.hash(:sha256, verifier), padding: false)
end
