defmodule Teiserver.Tachyon.System do
  @moduledoc false

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      Teiserver.Tachyon.Schema.cache_spec(),
      Teiserver.TachyonBattle.System,
      Teiserver.Autohost.System,
      Teiserver.Player.System
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
