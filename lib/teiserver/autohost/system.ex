defmodule Teiserver.Autohost.System do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [Teiserver.Autohost.Registry]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
