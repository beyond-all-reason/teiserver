defmodule Teiserver.Autohost.Registry do
  @moduledoc """
  Registry used for autohost using tachyon protocol

  Doesn't do much yet, can be used later for host selection for lobbies
  and matchmaking
  """

  alias Teiserver.Autohost.Autohost

  def start_link() do
    Horde.Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  how to reach a given autohost
  """
  @spec via_tuple(Autohost.id()) :: GenServer.name()
  def via_tuple(autohost_id) do
    {:via, Horde.Registry, {__MODULE__, autohost_id}}
  end

  @spec register(Autohost.id()) :: {:ok, pid()} | {:error, {:already_registered, pid()}}
  def register(autohost_id) do
    # this is needed because the process that handle the ws connection is spawned
    # by phoenix, so we can't spawn+register in the same step
    Horde.Registry.register(__MODULE__, via_tuple(autohost_id), autohost_id)
  end

  @spec lookup(Autohost.id()) :: pid() | nil
  def lookup(autohost_id) do
    case Horde.Registry.lookup(__MODULE__, via_tuple(autohost_id)) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  def child_spec(_) do
    Supervisor.child_spec(Horde.Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end
end
