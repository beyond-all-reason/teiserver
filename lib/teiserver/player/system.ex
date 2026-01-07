defmodule Teiserver.Player.System do
  @moduledoc """
  All things player related with tachyon, like connection and session
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      Teiserver.Player.SessionRegistry,
      Teiserver.Player.SessionSupervisor,
      Teiserver.Player.Registry,
      Supervisor.child_spec(
        {Teiserver.Tachyon.SyncTask, %{mfa: [Teiserver.Player.Session, :restore_sessions, []]}},
        id: RestoreSessionTask
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
