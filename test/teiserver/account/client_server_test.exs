defmodule Teiserver.Account.ClientServerTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.Client
  alias Teiserver.Account.ClientLib

  @tag :needs_attention
  test "server test" do
    client = %{
      userid: 1,
      name: "ClientServerTest User",
      country: "??",
      in_game: false,
      away: false,
      rank: 1,
      moderator: false,
      bot: false,
      ready: false,
      party_id: nil,
      player_number: 0,
      team_colour: "0",
      team_number: 0,
      player: false,
      handicap: 0,
      sync: 0,
      side: 0,
      role: "spectator",
      lobby_client: "BAR Lobby",
      lobby_id: nil
    }

    userid = client.userid

    p = ClientLib.start_client_server(client)
    assert is_pid(p)

    # crappy way to ensure the genserver is registered by the time
    # call_client is called.
    :timer.sleep(5)
    # Call it!
    c = ClientLib.call_client(userid, :get_client_state)
    assert c.userid == userid
    assert c.away == false
    assert c.lobby_client == "BAR Lobby"

    # Call one that doesn't exist
    c = ClientLib.call_client(-1, :get_client_state)
    assert c == nil

    # Partial update
    r = ClientLib.merge_update_client(userid, %{team_number: 1})
    assert r == :ok

    # Partial update with no client server
    r = ClientLib.merge_update_client(-1, %{team_number: 1})
    assert r == nil

    # Update client
    ClientLib.replace_update_client(Map.put(client, :side, 1), :client_updated_battlestatus)

    # No server
    # r = ClientLib.update_client(Map.merge(client, %{side: 1, userid: -1}), :client_updated_battlestatus)
    # assert r == nil

    Client.disconnect(userid)
    ClientLib.stop_client_server(userid)
  end
end
