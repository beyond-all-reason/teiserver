defmodule Teiserver.TachyonBattle.Supervisor do
  @moduledoc false

  use DynamicSupervisor
  alias Teiserver.TachyonBattle.Types, as: T
  alias Teiserver.TachyonBattle.Battle

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_battle(
          T.id(),
          T.match_id(),
          Teiserver.Autohost.id(),
          Teiserver.Autohost.start_script()
        ) ::
          DynamicSupervisor.on_start_child()
  def start_battle(battle_id, match_id, autohost_id, start_script) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Battle,
       %{
         battle_id: battle_id,
         match_id: match_id,
         autohost_id: autohost_id,
         start_script: start_script
       }}
    )
  end
end
