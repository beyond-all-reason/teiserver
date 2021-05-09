defmodule Teiserver.Protocols.Tachyon.BattleOut do
  alias Teiserver.Protocols.Tachyon

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
end
