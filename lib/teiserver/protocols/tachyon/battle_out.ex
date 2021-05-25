defmodule Teiserver.Protocols.Tachyon.BattleOut do
  alias Teiserver.Protocols.Tachyon
  alias Teiserver.Battle

  @spec do_reply(atom(), any) :: Map.t()

  ###########
  # Query
  def do_reply(:query, battle_list) do
    %{
      "cmd" => "s.battle.get_token",
      "result" => "success",
      "battles" => battle_list
        |> Enum.map(fn b -> Tachyon.convert_object(:battle, b) end)
    }
  end

  ###########
  # Create
  def do_reply(:create, {:success, battle}) do
    %{
      "cmd" => "s.battle.create",
      "result" => "success",
      "battle" => Tachyon.convert_object(:battle, battle)
    }
  end

  ###########
  # Leave
  def do_reply(:leave, {:success, nil}) do
    %{
      "cmd" => "s.battle.leave",
      "result" => "success"
    }
  end

  def do_reply(:leave, {:failure, reason}) do
    %{
      "cmd" => "s.battle.leave",
      "result" => "failure",
      "reason" => reason
    }
  end

  ###########
  # Join
  def do_reply(:join, :waiting) do
    %{
      "cmd" => "s.battle.join",
      "result" => "waiting_for_host"
    }
  end

  def do_reply(:join, {:failure, reason}) do
    %{
      "cmd" => "s.battle.join",
      "result" => "failure",
      "reason" => reason
    }
  end

  ###########
  # Join request
  def do_reply(:request_to_join, userid) do
    %{
      "cmd" => "s.battle.request_to_join",
      "userid" => userid
    }
  end

  ###########
  # Join response
  def do_reply(:join_response, {:approve, battle}) do
    %{
      "cmd" => "s.battle.join_response",
      "result" => "approve",
      "battle" => Tachyon.convert_object(:battle, battle)
    }
  end

  def do_reply(:join_response, {:reject, reason}) do
    %{
      "cmd" => "s.battle.join_response",
      "result" => "reject",
      "reason" => reason
    }
  end
end
