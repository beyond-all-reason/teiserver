defmodule Teiserver.Chat.RoomSystem do
  @moduledoc """
  Everything required for chat rooms with legacy protocol
  """
  alias Teiserver.Chat

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    children = [
      Chat.RoomRegistry,
      Chat.RoomSupervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
