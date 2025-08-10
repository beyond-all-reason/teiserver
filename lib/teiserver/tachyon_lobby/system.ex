defmodule Teiserver.TachyonLobby.System do
  @moduledoc """
  All the processes and supervisors to support lobbies (creation and listing)
  """

  use Supervisor

  alias Teiserver.TachyonLobby

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      TachyonLobby.Registry,
      TachyonLobby.Supervisor,
      TachyonLobby.List
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
