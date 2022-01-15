defmodule Teiserver.Protocols.Tachyon.V1.ClientOut do
  @spec do_reply(atom(), any) :: Map.t()

  ###########
  # Tokens
  def do_reply(:user_token, {:success, token}) do
    %{
      "cmd" => "s.auth.get_token",
      "result" => "success",
      "token" => token
    }
  end
end
