defmodule Teiserver.Autohost.System do
  @moduledoc false
  alias Teiserver.Autohost
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    children = [Autohost.Registry, Autohost.SessionRegistry, Autohost.SessionSupervisor]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
