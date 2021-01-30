defmodule Teiserver.Battle do
  def get_battle(id) do
    ConCache.get(:battles, id)
  end

  def add_battle(battle) do
    ConCache.put(:battles, battle.id, battle)
    ConCache.update(:lists, :battles, fn value -> 
      new_value = (value ++ [battle.id])
      |> Enum.uniq

      {:ok, new_value}
    end)
  end

  def list_battles() do
    ConCache.get(:lists, :battles)
    |> Enum.map(fn battle_id -> ConCache.get(:battles, battle_id) end)
  end
end