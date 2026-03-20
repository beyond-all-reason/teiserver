defmodule Teiserver.TachyonBattle.System do
  alias Teiserver.TachyonBattle
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_) do
    children = [TachyonBattle.Supervisor, TachyonBattle.Registry]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
