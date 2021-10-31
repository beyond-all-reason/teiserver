defmodule Teiserver.Protocols.Tachyon.Dev.CommunicationIn do
  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("get_latest_game_news", _cmd, state) do
    state
  end
end
