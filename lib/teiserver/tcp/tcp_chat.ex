defmodule Teiserver.Tcp.TcpChat do
  alias Teiserver.Data.Types, as: T

  @spec do_handle({:say | :sayex, T.lobby_id(), T.userid(), String.t}, Map.t()) :: Map.t()
  def do_handle({_action, _lobby_id, _userid, _msg}, state) do
    state
  end
end
