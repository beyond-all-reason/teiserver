defmodule Teiserver.Tachyon.System do
  @moduledoc false

  alias Teiserver.Autohost
  alias Teiserver.Matchmaking
  alias Teiserver.Party
  alias Teiserver.Player

  alias Teiserver.Tachyon.Schema
  alias Teiserver.TachyonBattle
  alias Teiserver.TachyonLobby

  use Supervisor

  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_arg) do
    children = [
      Schema.cache_spec(),
      Autohost.System,
      TachyonBattle.System,
      Matchmaking.System,
      TachyonLobby.System,
      Party.System,
      Player.System
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  restart the entire tachyon system
  """
  def restart do
    :ok = Supervisor.terminate_child(Teiserver.Supervisor, __MODULE__)
    {:ok, _pid} = Supervisor.restart_child(Teiserver.Supervisor, __MODULE__)
  end
end
