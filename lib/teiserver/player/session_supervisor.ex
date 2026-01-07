defmodule Teiserver.Player.SessionSupervisor do
  @moduledoc """
  Supervise player's session
  """

  use DynamicSupervisor

  @doc """
  To be called by a connection handler to ensure a session is setup.
  """
  def start_session(user) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Teiserver.Player.Session, {user.id, {:manual, self(), user}}}
    )
  end

  @doc """
  When restoring a session at startup from a snapshotted state
  """
  def start_session_from_snapshot(user_id, snapshot) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Teiserver.Player.Session, {user_id, {:snapshot, snapshot}}}
    )
  end

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
