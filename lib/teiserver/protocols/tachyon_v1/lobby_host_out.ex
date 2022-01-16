defmodule Teiserver.Protocols.Tachyon.V1.LobbyHostOut do
  alias Teiserver.Protocols.Tachyon.V1.Tachyon

  @spec do_reply(atom(), any) :: Map.t()

  ###########
  # Query
  def do_reply(:user_requests_to_join, {userid, script_password}) do
    %{
      "cmd" => "s.lobby_host.user_requests_to_join",
      "userid" => userid,
      "script_password" => script_password
    }
  end

  ###########
  # Join response
  def do_reply(:join_response, {:approve, lobby}) do
    %{
      "cmd" => "s.lobby_host.join_response",
      "result" => "approve",
      "lobby" => Tachyon.convert_object(:lobby, lobby)
    }
  end

  def do_reply(:join_response, {:reject, reason}) do
    %{
      "cmd" => "s.lobby_host.join_response",
      "result" => "reject",
      "reason" => reason
    }
  end
end
