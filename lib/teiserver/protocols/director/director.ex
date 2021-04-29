defmodule Teiserver.Protocols.Director do
  alias Teiserver.Battle
  alias Teiserver.Data.Types
  require Logger

  @spec handle_in(Types.userid(), String.t(), Types.battle_id()) :: :say | :handled
  def handle_in(userid, msg, battle_id) do
    battle = Battle.get_battle!(battle_id)

    cond do
      battle.director_mode == false ->
        :say

      String.slice(msg, 0..0) != "!" ->
        :say

      true ->
        parse_and_handle(userid, msg, battle)
        :handled
    end
  end

  @spec parse_and_handle(Types.userid(), String.t(), Map.t()) :: :ok
  defp parse_and_handle(userid, msg, battle) do
    [cmd, opts] = case String.split(msg, " ", parts: 2) do
      [cmd] -> [cmd, []]
      [cmd, parts] -> [cmd, String.split(parts, " ")]
    end
    do_handle(userid, cmd, opts, battle)
    :ok
  end

  @spec do_handle(Types.userid(), String.t(), [String.t()], Map.t()) :: :nomatch | :ok
  defp do_handle(_userid, "!start", _opts, battle) do
    send_to_host(battle, "!start")
  end

  defp do_handle(_, cmd, opts, _) do
    msg = "#{cmd}: #{Kernel.inspect(opts)}"
    Logger.error("director handle error: #{msg}")
    :nomatch
  end

  @spec send_to_host(Map.t(), String.t()) :: :ok
  defp send_to_host(battle, msg) do
    Logger.info("send_to_host - #{battle.id}, #{msg}")
    :ok
  end
end
