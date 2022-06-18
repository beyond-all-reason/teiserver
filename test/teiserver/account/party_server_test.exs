defmodule Teiserver.Account.PartyServerTest do
  use Central.DataCase, async: true
  alias Teiserver.Account.PartyLib

  # test "server test" do
  #   p = PartyLib.start_party_server()
  #   assert is_pid(p)

  #   # Call it!
  #   c = ClientLib.call_client(userid, :get_client_state)
  #   assert c.userid == userid
  #   assert c.away == false
  #   assert c.lobby_client == "BAR Lobby"

  #   # Call one that doesn't exist
  #   c = ClientLib.call_client(-1, :get_client_state)
  #   assert c == nil

  #   # Partial update
  #   r = ClientLib.merge_update_client(%{userid: userid, team_number: 1}, :client_updated_battlestatus)
  #   assert r == :ok

  #   # Partial update with no client server
  #   r = ClientLib.merge_update_client(%{userid: -1, team_number: 1}, :client_updated_battlestatus)
  #   assert r == nil


  #   # Update client
  #   r = ClientLib.update_client(Map.put(client, :side, 1), :client_updated_battlestatus)
  #   assert r != nil

  #   # No server
  #   # r = ClientLib.update_client(Map.merge(client, %{side: 1, userid: -1}), :client_updated_battlestatus)
  #   # assert r == nil

  #   ClientLib.stop_client_server(userid)
  # end
end
