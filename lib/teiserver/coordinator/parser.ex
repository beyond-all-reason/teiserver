defmodule Teiserver.Coordinator.Parser do
  require Logger
  alias Teiserver.Coordinator
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Battle.Lobby

  @spec handle_in(Types.userid(), String.t(), Types.lobby_id()) :: :say | :handled
  def handle_in(userid, msg, lobby_id) do
    battle = Lobby.get_battle!(lobby_id)

    cond do
      String.slice(msg, 0..0) == "£" ->
        parse_and_handle(userid, msg, battle)

      battle.coordinator_mode == false ->
        :say

      String.slice(msg, 0..1) == "! " ->
        :say

      String.slice(msg, 0..0) != "!" ->
        :say

      true ->
        parse_and_handle(userid, msg, battle)
    end
  end

  @spec parse_and_handle(Types.userid(), String.t(), Map.t()) :: :handled
  defp parse_and_handle(userid, msg, battle) do
    cmd = parse_command(userid, msg)
    Coordinator.cast_consul(battle.id, cmd)
    :handled
  end

  # @spec do_handle(Map.t(), Map.t()) :: :nomatch | :ok
  # defp do_handle(%{command: nil}, _battle), do: :nomatch

  # defp do_handle(%{command: "forcestart"} = cmd, battle) do
  #   send_to_host(cmd.sender, battle.id, "!forcestart")
  # end

  # defp do_handle(%{command: "welcome-message"} = cmd, battle) do
  #   cast_to_consul(battle, cmd)
  # end

  # defp do_handle(%{command: "Coordinator"} = cmd, battle) do
  #   cast_to_consul(battle, cmd)
  # end

  # defp do_handle(%{command: command}, _battle) do
  #   Logger.error("Coordinator no handler for cmd: #{command}")
  #   :nomatch
  # end


  @spec parse_command(T.userid(), String.t()) :: Map.t()
  def parse_command(userid, string) do
    %{
      raw: string,
      remaining: string,
      vote: false,
      force: false,
      silent: false,
      command: nil,
      error: nil,
      senderid: userid
    }
    |> strip_force_consul
    |> parse_silence
    |> parse_command_mode
    |> parse_command_name
  end

  defp strip_force_consul(%{remaining: remaining} = cmd) do
    case String.slice(remaining, 0..0) == "£" do
      true ->
        %{cmd | remaining: String.slice(remaining, 1, 2048)}
      false ->
        cmd
    end
  end

  defp parse_silence(%{remaining: remaining} = cmd) do
    case String.slice(remaining, 0..1) == "%!" do
      true ->
        %{cmd | silent: true, remaining: String.slice(remaining, 1, 2048)}
      false ->
        cmd
    end
  end

  @spec parse_command_mode(Map.t()) :: Map.t()
  defp parse_command_mode(%{remaining: string} = cmd) do
    cond do
      String.slice(string, 0, 4) == "!cv " ->
        %{cmd | vote: true, remaining: "!" <> String.slice(string, 4, 2048)}

      String.slice(string, 0, 6) == "!vote " ->
        %{cmd | vote: true, remaining: "!" <> String.slice(string, 6, 2048)}

      String.slice(string, 0, 7) == "!force " ->
        %{cmd | force: true, remaining: "!" <> String.slice(string, 7, 2048)}

      true ->
        cmd
    end
  end

  @spec parse_command_name(Map.t()) :: Map.t()
  defp parse_command_name(%{remaining: string} = cmd) do
    case Regex.run(~r/!([a-z0-9\-]+) ?/, string) do
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
