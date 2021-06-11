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
    parse_command(userid, msg)
    |> do_handle(battle)
  end

  @spec do_handle(Map.t(), Map.t()) :: :nomatch | :ok
  defp do_handle(%{command: nil}, _battle), do: :nomatch

  defp do_handle(%{command: "forcestart"} = cmd, battle) do
    send_to_host(cmd.sender, battle, "!forcestart")
  end

  defp do_handle(%{command: "welcome-message"} = cmd, battle) do
    send_to_consul(battle, cmd)
  end

  defp do_handle(%{command: "director"} = cmd, battle) do
    send_to_consul(battle, cmd)
  end

  defp do_handle(%{command: command}, _battle) do
    Logger.error("director no handler for cmd: #{command}")
    :nomatch
  end

  @spec send_to_host(T.userid(), Map.t(), String.t()) :: :ok
  defp send_to_host(from_id, battle, msg) do
    Director.send_to_host(from_id, battle, msg)
    :ok
  end

  @spec send_to_consul(Map.t(), Map.t()) :: :ok
  defp send_to_consul(battle, cmd) do
    send(battle.consul_pid, cmd)
    :ok
  end

  @spec parse_command(T.userid(), String.t()) :: Map.t()
  def parse_command(userid, string) do
    %{
      raw: string,
      remaining: string,
      vote: false,
      command: nil,
      senderid: userid
    }
    |> parse_command_cv
    |> parse_command_name
  end

  @spec parse_command_cv(Map.t()) :: Map.t()
  defp parse_command_cv(%{remaining: string} = cmd) do
    if String.slice(string, 0, 4) == "!cv " do
      %{cmd | vote: true, remaining: "!" <> String.slice(string, 4, 1024)}
    else
      cmd
    end
  end

  @spec parse_command_name(Map.t()) :: Map.t()
  defp parse_command_name(%{remaining: string} = cmd) do
    case Regex.run(~r/!([a-z0-9\-]+) /, string) do
      [_, command_name] ->
        %{cmd |
          command: command_name,
          remaining: String.slice(string, String.length(command_name) + 2, 999)
        }
      _ ->
        cmd
    end
  end
end
