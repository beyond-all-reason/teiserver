defmodule Teiserver.Tcp.TcpChat do
  alias Teiserver.Data.Types, as: T

  @spec do_handle({:say | :sayex, T.lobby_id(), T.userid(), String.t}, Map.t()) :: Map.t()
  def do_handle({action, lobby_id, userid, msg}, state) do
    state
  end
end
