defmodule Teiserver.Tcp.TcpLobby do
  require Logger

  def handle_info({:global_battle_lobby, :rename, lobby_id}, state) do
    state.protocol_out.reply(:battle, :lobby_rename, lobby_id, nil, state)
  end

  def handle_info({:global_battle_lobby, _action, _lobby_id}, state) do
    state
  end

  def handle_info({:client_message, :lobby, _userid, _data}, state) do
    state
  end
end
