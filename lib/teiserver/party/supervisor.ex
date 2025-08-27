defmodule Teiserver.Party.Supervisor do
  @moduledoc """
  Supervise player's parties
  """

  use DynamicSupervisor

  alias Teiserver.Party
  alias Teiserver.Data.Types, as: T

  @doc """
  Create a new party
  """
  @spec start_party(Party.Server.id(), T.userid(), pid()) ::
          DynamicSupervisor.on_start_child()
  def start_party(party_id, user_id, creator_pid) do
    DynamicSupervisor.start_child(__MODULE__, {Teiserver.Party.Server, {party_id, user_id, creator_pid}})
  end

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
