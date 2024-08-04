defmodule Teiserver.Player.SessionSupervisor do
  @moduledoc """
  Supervise player's session
  """

  use DynamicSupervisor

  @doc """
  To be called by a connection handler to ensure a session is setup.
  """
  def start_session(user_id) do
    DynamicSupervisor.start_child(__MODULE__, {Teiserver.Player.Session, {self(), user_id}})
  end

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
