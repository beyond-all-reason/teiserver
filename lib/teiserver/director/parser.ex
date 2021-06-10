defmodule Teiserver.Director.Parser do
  require Logger
  alias Teiserver.Director
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Battle.BattleLobby

  @spec handle_in(Types.userid(), String.t(), Types.battle_id()) :: :say | :handled
  def handle_in(userid, msg, battle_id) do
    battle = BattleLobby.get_battle!(battle_id)

    cond do
      battle.director_mode == false ->
        :say

      String.slice(msg, 0..0) != "!" ->
        :say

      true ->
        case parse_and_handle(userid, msg, battle) do
          :ok ->
            :handled
          :nomatch ->
            :say
        end
    end
  end

  @spec parse_and_handle(Types.userid(), String.t(), Map.t()) :: :ok
  defp parse_and_handle(userid, msg, battle) do
    [cmd, opts] =
      case String.split(msg, " ", parts: 2) do
        [cmd] -> [cmd, []]
        [cmd, parts] -> [cmd, String.split(parts, " ")]
      end

    do_handle(userid, cmd, opts, battle)
  end

  @spec do_handle(Types.userid(), String.t(), [String.t()], Map.t()) :: :nomatch | :ok
  defp do_handle(from_id, "!start", _opts, battle) do
    send_to_host(from_id, battle, "!forcestart")
    :ok
  end

  defp do_handle(_, cmd, opts, _) do
    msg = "#{cmd}: #{Kernel.inspect(opts)}"
    Logger.error("director handle error: #{msg}")
    :nomatch
  end

  @spec send_to_host(T.userid(), Map.t(), String.t()) :: :ok
  defp send_to_host(from_id, battle, msg) do
    Director.send_to_host(from_id, battle, msg)
    :ok
  end
end
