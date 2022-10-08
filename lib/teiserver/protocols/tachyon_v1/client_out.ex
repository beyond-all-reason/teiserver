defmodule Teiserver.Protocols.Tachyon.V1.ClientOut do
  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:client_list, clients) do
    %{
      cmd: "s.client.client_list",
      clients: clients
    }
  end

  def do_reply(:connected, userid) do
    %{
      cmd: "s.client.connected",
      userid: userid
    }
  end

  def do_reply(:disconnected, userid) do
    %{
      cmd: "s.client.disconnected",
      userid: userid
    }
  end

  def do_reply(:added_to_party, {userid, party_id}) do
    %{
      cmd: "s.client.added_to_party",
      userid: userid,
      party_id: party_id
    }
  end

  def do_reply(:left_party, {userid, party_id}) do
    %{
      cmd: "s.client.left_party",
      userid: userid,
      party_id: party_id
    }
  end

  def do_reply(:added_to_lobby, {userid, lobby_id}) do
    %{
      cmd: "s.client.added_to_lobby",
      userid: userid,
      lobby_id: lobby_id
    }
  end

  def do_reply(:left_lobby, {userid, lobby_id}) do
    %{
      cmd: "s.client.left_lobby",
      userid: userid,
      lobby_id: lobby_id
    }
  end
end
