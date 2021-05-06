defmodule Teiserver.Protocols.Tachyon.AuthOut do

  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:user_token, {:success, token}) do
    %{
      "cmd" => "s.auth.get_token",
      "outcome" => "success",
      "token" => token
    }
  end

  def do_reply(:user_token, {:failure, reason}) do
    %{
      "cmd" => "s.auth.get_token",
      "outcome" => "failure",
      "reason" => reason
    }
  end
end
